import Foundation
import AVFoundation
import AppKit
import Combine // Import Combine for objectWillChange

class VideoConverter: ObservableObject {

    // MARK: - Published Properties for UI Binding & Batch State
    // @Published var fileQueue: [FileQueueItem] = [] // This publishes changes *to the array itself* (add/remove)
    // For changes *within* elements of the array, we rely on replacing the element.
    // If rows still don't update, we might need to manually trigger objectWillChange more often.
    var fileQueue: [FileQueueItem] = [] {
        willSet {
            // This will fire if the entire array reference changes,
            // but not always for mutations of elements within if not handled carefully.
            // For element changes, we explicitly call objectWillChange.send() if needed.
            // However, the common pattern is self.fileQueue[index] = newVersionOfItem
            // which should trigger @Published correctly.
        }
        didSet {
             // If you assign a whole new array to fileQueue, @Published handles it.
        }
    }
    // We will manually call objectWillChange.send() before array modifications
    // if simply replacing the element doesn't work.

    @Published var isBatchConverting: Bool = false
    @Published var overallProgressMessage: String = ""
    @Published var globalErrorMessage: String? = nil
    @Published var showOutputDirectorySelector: Bool = false

    // MARK: - Published Settings
    @Published var outputFormat: OutputFormat = .mp4
    @Published var videoQuality: VideoQuality = .medium
    @Published var audioCodec: AudioCodec = .aac
    @Published var videoCodec: VideoCodec = .h264

    // MARK: - Private Properties
    private let commandBuilder = FFmpegCommandBuilder()
    private let processRunner = FFmpegProcessRunner()
    private var currentConvertingItemIndex: Int? = nil
    private var selectedOutputDirectory: URL? = nil
    
    // To manually signal SwiftUI about changes if needed.
    let objectWillChange = PassthroughSubject<Void, Never>()


    init() {
        processRunner.delegate = self
        print("VideoConverter initialized for batch processing.")
    }

    // ... (addFilesToQueue, clearQueue, removeItemFromQueue, selectOutputDirectoryAndStartBatch, startBatchConversion are mostly the same) ...
    // Ensure securityScopedInputURL is correctly passed in addFilesToQueue:
    func addFilesToQueue(urls: [URL], accessAlreadyStarted: Bool = false) { // Added accessAlreadyStarted with a default
        DispatchQueue.main.async {
            self.objectWillChange.send() // Signal before array modification
            self.globalErrorMessage = nil
            let newItems = urls.compactMap { url -> FileQueueItem? in
                var itemScopedURL = url // This will be the URL stored for security scope management

                if !accessAlreadyStarted {
                    // This path would be taken if access wasn't started by the caller.
                    // For files from "Add Files" button, FileUtilities.selectFiles *does* start access,
                    // so 'accessAlreadyStarted' should be true.
                    // If for some reason access wasn't started, we attempt it here.
                    if !url.startAccessingSecurityScopedResource() {
                        print("AddFilesToQueue: Failed to start security access for \(url.lastPathComponent) when accessAlreadyStarted was false. It might fail during conversion.")
                        // We might still add it, but it's unlikely to work if access couldn't be started.
                        // Or, you could choose to not add it: return nil
                    }
                    // If the above call succeeded, itemScopedURL (which is 'url') now has access.
                }
                // If accessAlreadyStarted is true, we assume 'url' (passed as itemScopedURL) already has access.
                return FileQueueItem(inputURL: url, securityScopedInputURL: itemScopedURL)
            }
            self.fileQueue.append(contentsOf: newItems)
        }
    }
    
    func clearQueue() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.cancelBatchConversion(userInitiated: false)
            self.fileQueue.removeAll()
            self.currentConvertingItemIndex = nil
            self.isBatchConverting = false
            self.overallProgressMessage = ""
            self.globalErrorMessage = nil
            self.selectedOutputDirectory = nil
        }
    }

    func removeItemFromQueue(at offsets: IndexSet) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            // ... (rest of removeItemFromQueue logic, ensure security scope stop) ...
            for index in offsets.reversed() {
                if let currentIndex = self.currentConvertingItemIndex, index == currentIndex {
                    self.cancelCurrentConversionOnly()
                }
                if index < self.fileQueue.count {
                    self.fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
                }
            }
            self.fileQueue.remove(atOffsets: offsets)
        }
    }
    
    func selectOutputDirectoryAndStartBatch() { // No objectWillChange needed here as it calls startBatchConversion
        guard !fileQueue.isEmpty else {
            globalErrorMessage = "No files in the queue to convert."
            return
        }
        guard !isBatchConverting else {
            globalErrorMessage = "A batch conversion is already in progress."
            return
        }

        if let directoryURL = FileUtilities.chooseOutputDirectory() {
            self.selectedOutputDirectory = directoryURL
            self.startBatchConversion()
        } else {
            print("User cancelled output directory selection.")
        }
    }

    private func startBatchConversion() { // No objectWillChange needed at start, but for item updates
        guard selectedOutputDirectory != nil else {
            globalErrorMessage = "Output directory not selected."; return
        }
        guard !fileQueue.isEmpty else {
            globalErrorMessage = "Queue is empty."; isBatchConverting = false; return
        }

        DispatchQueue.main.async {
            // self.objectWillChange.send() // Not for these top-level @Published vars
            self.isBatchConverting = true
            self.globalErrorMessage = nil
            
            // Manually signal for array content reset if simple assignment doesn't update UI
            self.objectWillChange.send()
            for i in self.fileQueue.indices {
                if self.fileQueue[i].status != .pending && self.fileQueue[i].status != .converting && self.fileQueue[i].status != .preparing {
                    self.fileQueue[i].status = .pending
                    self.fileQueue[i].progress = 0.0
                    self.fileQueue[i].errorMessage = nil
                    self.fileQueue[i].successMessage = nil
                }
            }
            self.processNextItemInQueue()
        }
    }


    // In processNextItemInQueue, before self.fileQueue[nextItemIndex] = item
    private func processNextItemInQueue() {
        DispatchQueue.main.async {
            // Stop security access for the previously converting item, if any and if it's truly done
            if let prevIndex = self.currentConvertingItemIndex, prevIndex < self.fileQueue.count {
                let prevItem = self.fileQueue[prevIndex]
                if prevItem.status != .converting && prevItem.status != .preparing { // Only stop if not actively being worked on
                    prevItem.securityScopedInputURL?.stopAccessingSecurityScopedResource()
                    // No need to nil out self.fileQueue[prevIndex].securityScopedInputURL, it's part of the item's data
                }
            }
            self.currentConvertingItemIndex = nil // Reset before finding the next one

            // Find the actual next item index
            guard let actualNextItemIndex = self.fileQueue.firstIndex(where: { $0.status == .pending }) else {
                self.overallProgressMessage = "Batch completed."
                self.isBatchConverting = false
                self.selectedOutputDirectory = nil // Clear after batch is done
                self.objectWillChange.send() // Send change for overallProgressMessage and isBatchConverting
                print("No more pending items in queue.")
                return
            }

            // Now, use 'actualNextItemIndex' throughout this processing block
            self.currentConvertingItemIndex = actualNextItemIndex
            
            self.objectWillChange.send() // Signal change before updating item in array
            var currentItem = self.fileQueue[actualNextItemIndex] // Make a mutable copy using the correct index
            currentItem.status = .preparing
            self.fileQueue[actualNextItemIndex] = currentItem // Assign back to trigger UI

            let completedCount = self.fileQueue.filter { $0.status == .completed }.count
            self.overallProgressMessage = "Preparing \(currentItem.inputURL.lastPathComponent) (\(completedCount + 1) of \(self.fileQueue.count))"
            self.objectWillChange.send() // For overallProgressMessage update

            // Use currentItem for its properties from here
            guard let currentItemScopedURL = currentItem.securityScopedInputURL, currentItemScopedURL.startAccessingSecurityScopedResource() else {
                print("Failed to get security access for \(currentItem.inputURL.lastPathComponent)")
                // Use actualNextItemIndex for updateItemStatus
                self.updateItemStatus(at: actualNextItemIndex, status: .failed, errorMessage: "Could not access input file. Please re-add it.")
                self.processNextItemInQueue() // Try next one
                return
            }

            guard let outputDir = self.selectedOutputDirectory else {
                self.updateItemStatus(at: actualNextItemIndex, status: .failed, errorMessage: "Output directory is missing.")
                currentItemScopedURL.stopAccessingSecurityScopedResource() // Stop access since we are failing
                self.processNextItemInQueue()
                return
            }

            let outputFilename = currentItem.inputURL.deletingPathExtension().lastPathComponent
            let outputFileURL = outputDir.appendingPathComponent(outputFilename).appendingPathExtension(self.outputFormat.rawValue)
            
            self.objectWillChange.send() // Signal change before updating item in array for outputURL
            currentItem.outputURL = outputFileURL // Update the mutable copy
            self.fileQueue[actualNextItemIndex] = currentItem // Assign back

            if FileManager.default.fileExists(atPath: outputFileURL.path) {
                 print("Output file \(outputFileURL.lastPathComponent) exists. FFmpeg will overwrite.")
            }

            guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
                self.updateItemStatus(at: actualNextItemIndex, status: .failed, errorMessage: "FFmpeg not found.")
                currentItemScopedURL.stopAccessingSecurityScopedResource() // Stop access
                self.processNextItemInQueue()
                return
            }

            let arguments = self.commandBuilder.buildCommand(
                inputURL: currentItem.inputURL, // Use original inputURL from the item for ffmpeg
                outputURL: outputFileURL,
                outputFormat: self.outputFormat,
                videoCodec: self.videoCodec,
                videoQuality: self.videoQuality,
                audioCodec: self.audioCodec
            )

            // Update status to converting *before* running the process
            // Use actualNextItemIndex for updateItemStatus
            self.updateItemStatus(at: actualNextItemIndex, status: .converting, progress: 0.0)
            let totalCompletedNow = self.fileQueue.filter({$0.status == .completed}).count
            // This item is now being processed, so it's effectively the (totalCompletedNow + 1)-th item in sequence of processing
            let processingNumber = totalCompletedNow + 1
            self.overallProgressMessage = "Converting \(currentItem.inputURL.lastPathComponent) (\(processingNumber) of \(self.fileQueue.count))"
            self.objectWillChange.send() // For overallProgressMessage update

            // Pass currentItem.inputURL (the original non-scoped URL) to ffmpeg runner
            self.processRunner.run(ffmpegPath: ffmpegPath, arguments: arguments, inputURL: currentItem.inputURL)
        }
    }
    
    func cancelBatchConversion(userInitiated: Bool = true) {
        DispatchQueue.main.async {
            self.objectWillChange.send() // Signal change before modifying queue
            // ... (rest of cancelBatchConversion logic) ...
            if !self.isBatchConverting && self.currentConvertingItemIndex == nil {
                for i in self.fileQueue.indices where self.fileQueue[i].status == .pending {
                    self.fileQueue[i].securityScopedInputURL?.stopAccessingSecurityScopedResource()
                    if userInitiated { self.fileQueue[i].status = .cancelled }
                }
                if userInitiated { self.overallProgressMessage = "Batch cancelled." }
                return
            }

            self.isBatchConverting = false
            if let currentIndex = self.currentConvertingItemIndex, currentIndex < self.fileQueue.count {
                self.processRunner.cancel()
                // Delegate call will update status, but also set explicitly here for immediate UI feedback
                self.fileQueue[currentIndex].status = .cancelled
                self.fileQueue[currentIndex].errorMessage = userInitiated ? "Cancelled by user" : self.fileQueue[currentIndex].errorMessage
                self.fileQueue[currentIndex].securityScopedInputURL?.stopAccessingSecurityScopedResource()
            }
            for i in self.fileQueue.indices {
                if self.fileQueue[i].status == .pending || self.fileQueue[i].status == .preparing {
                    self.fileQueue[i].status = .cancelled
                    self.fileQueue[i].securityScopedInputURL?.stopAccessingSecurityScopedResource()
                }
            }
            self.currentConvertingItemIndex = nil
            if userInitiated { self.overallProgressMessage = "Batch cancelled." }
        }
    }

    private func cancelCurrentConversionOnly() {
        DispatchQueue.main.async {
             if let currentIndex = self.currentConvertingItemIndex,
               currentIndex < self.fileQueue.count,
               (self.fileQueue[currentIndex].status == .converting || self.fileQueue[currentIndex].status == .preparing) {
                self.objectWillChange.send() // Signal before changing item status
                self.processRunner.cancel() // This will trigger delegate methods
                self.fileQueue[currentIndex].status = .cancelled // Update status immediately
                self.fileQueue[currentIndex].errorMessage = "Cancelled by user"
                // Delegate method will handle stopping security scope and calling processNext
            }
        }
    }


    // This is the main function for updating an item's state and triggering UI refresh
    private func updateItemStatus(at index: Int, status: ConversionStatus, progress: Double? = nil, errorMessage: String? = nil, successMessage: String? = nil) {
        guard index >= 0 && index < fileQueue.count else {
            print("Error: Attempted to update item at invalid index \(index). Queue count: \(fileQueue.count)")
            return
        }
        DispatchQueue.main.async {
            self.objectWillChange.send() // Explicitly tell SwiftUI something is about to change

            var itemToUpdate = self.fileQueue[index]
            itemToUpdate.status = status
            if let progressVal = progress { itemToUpdate.progress = progressVal }
            
            // Clear previous messages if not providing new ones for that type
            itemToUpdate.errorMessage = (status == .failed || status == .cancelled) ? errorMessage : nil
            itemToUpdate.successMessage = (status == .completed) ? successMessage : nil
            
            self.fileQueue[index] = itemToUpdate // Replace the item in the array
        }
    }
}

// MARK: - FFmpegProcessRunnerDelegate Extension
extension VideoConverter: FFmpegProcessRunnerDelegate {

    func processRunnerDidUpdateProgress(_ progress: Double) {
        guard let currentIndex = currentConvertingItemIndex, currentIndex < fileQueue.count else { return }
        // updateItemStatus will call objectWillChange.send()
        updateItemStatus(at: currentIndex, status: .converting, progress: progress)
    }

    func processRunnerDidFailWithError(_ error: String) {
        guard let currentIndex = currentConvertingItemIndex, currentIndex < fileQueue.count else {
            print("Delegate error but no current item: \(error)")
            if isBatchConverting { processNextItemInQueue() }
            return
        }

        let isUserCancel = (error.lowercased().contains("cancelled") || error.lowercased().contains("operation cancelled"))
        let finalStatus: ConversionStatus = isUserCancel ? .cancelled : .failed
        // If user cancelled, use existing item.errorMessage (set by cancelCurrentConversionOnly) or a default
        let finalMessage = isUserCancel ? (self.fileQueue[currentIndex].errorMessage ?? "Cancelled") : "Conversion Failed: \(error)"
        
        updateItemStatus(at: currentIndex, status: finalStatus, errorMessage: finalMessage)
        self.fileQueue[currentIndex].securityScopedInputURL?.stopAccessingSecurityScopedResource()

        if isBatchConverting {
            processNextItemInQueue()
        } else {
            self.currentConvertingItemIndex = nil
            self.overallProgressMessage = "Batch stopped."
        }
    }

    func processRunnerDidFinish() {
        guard let currentIndex = currentConvertingItemIndex, currentIndex < fileQueue.count else {
            print("Delegate finish but no current item.")
            if isBatchConverting { processNextItemInQueue() }
            return
        }
        let item = fileQueue[currentIndex] // Get a non-mutable copy for reading
        var finalSuccessMessage = "Completed: \(item.outputURL?.lastPathComponent ?? "File")"
        var compressionInfo = ""

        let originalURL = item.inputURL
        if let outputURL = item.outputURL {
            var originalSizeValue: Int64?
            var couldAccessInputForSize = false

            if let scopedURL = item.securityScopedInputURL, scopedURL.startAccessingSecurityScopedResource() {
                originalSizeValue = FileUtilities.getFileSize(url: originalURL)
                scopedURL.stopAccessingSecurityScopedResource()
                couldAccessInputForSize = originalSizeValue != nil
            }
            if !couldAccessInputForSize {
                 print("Could not use securityScopedInputURL for size check of \(originalURL.lastPathComponent). Attempting direct (might fail).")
                 originalSizeValue = FileUtilities.getFileSize(url: originalURL)
            }
            let newSize = FileUtilities.getFileSize(url: outputURL)

            if let oSize = originalSizeValue, let nSize = newSize {
                let fOSize = FileUtilities.formatBytes(oSize); let fNSize = FileUtilities.formatBytes(nSize)
                compressionInfo += "\nOriginal: \(fOSize), New: \(fNSize)."
                if oSize > 0 {
                    if nSize < oSize { compressionInfo += String(format: " Reduced by %.1f%%.", (Double(oSize - nSize)/Double(oSize))*100) }
                    else if nSize > oSize { compressionInfo += String(format: " Increased by %.1f%%.", (Double(nSize-oSize)/Double(oSize))*100) }
                    else { compressionInfo += " File size is the same." }
                }
            } else {
                compressionInfo += "\nSizes: Orig(\(originalSizeValue != nil ? "✓" : "x")) New(\(newSize != nil ? "✓" : "x"))"
            }
        } else { compressionInfo += "\nOutput URL not found." }
        finalSuccessMessage += compressionInfo
        
        updateItemStatus(at: currentIndex, status: .completed, successMessage: finalSuccessMessage)
        self.fileQueue[currentIndex].securityScopedInputURL?.stopAccessingSecurityScopedResource()

        if isBatchConverting {
            processNextItemInQueue()
        } else {
            self.currentConvertingItemIndex = nil
            self.overallProgressMessage = "Batch stopped."
        }
    }
}
