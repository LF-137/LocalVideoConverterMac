import Foundation
import Combine

@MainActor
class VideoConverter: ObservableObject {

    // MARK: - Published Properties
    @Published var fileQueue: [FileQueueItem] = []
    @Published var isBatchConverting: Bool = false
    @Published var overallProgressMessage: String = ""
    @Published var globalErrorMessage: String? = nil
    
    // Settings
    @Published var outputFormat: OutputFormat = .mp4
    @Published var videoQuality: VideoQuality = .medium
    @Published var audioCodec: AudioCodec = .aac
    @Published var videoCodec: VideoCodec = .h264

    // MARK: - Internal State
    private let commandBuilder = FFmpegCommandBuilder()
    private let processRunner = FFmpegProcessRunner()
    private var currentItemIndex: Int? = nil
    private var outputDirectory: URL? = nil

    init() {
        processRunner.delegate = self
    }

    // MARK: - Queue Management
    
    func addFiles(urls: [URL]) {
        self.globalErrorMessage = nil
        
        for url in urls {
            // Attempt to create a bookmark or maintain access
            var scopedURL = url
            let isScoped = url.startAccessingSecurityScopedResource()
            if !isScoped {
                print("Warning: Could not start accessing security scoped resource for \(url.lastPathComponent)")
            }
            
            let item = FileQueueItem(
                inputURL: url,
                securityScopedInputURL: isScoped ? scopedURL : nil,
                status: .pending
            )
            fileQueue.append(item)
        }
    }

    func clearQueue() {
        cancelBatch()
        // Stop accessing all resources
        fileQueue.forEach { $0.securityScopedInputURL?.stopAccessingSecurityScopedResource() }
        fileQueue.removeAll()
        globalErrorMessage = nil
        overallProgressMessage = ""
    }

    func removeItems(at offsets: IndexSet) {
        // Stop access for removed items
        offsets.forEach { index in
            fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
            if index == currentItemIndex {
                cancelBatch()
            }
        }
        fileQueue.remove(atOffsets: offsets)
        
        // Reset state if queue becomes empty
        if fileQueue.isEmpty {
            isBatchConverting = false
            currentItemIndex = nil
        }
    }

    // MARK: - Batch Processing

    func startBatch() {
        guard !fileQueue.isEmpty else { return }
        
        FileUtilities.chooseOutputDirectory { [weak self] url in
            guard let self = self, let url = url else { return }
            self.outputDirectory = url
            self.runBatchSequence()
        }
    }

    private func runBatchSequence() {
        isBatchConverting = true
        globalErrorMessage = nil
        
        // Reset completed items if restarting? (Optional, currently checks for pending)
        // Find next pending
        guard let index = fileQueue.firstIndex(where: { $0.status == .pending }) else {
            finishBatch()
            return
        }
        
        startConversion(at: index)
    }

    private func startConversion(at index: Int) {
        currentItemIndex = index
        var item = fileQueue[index]
        
        // Update UI
        item.status = .preparing
        item.errorMessage = nil
        fileQueue[index] = item
        
        let count = fileQueue.count
        let processed = fileQueue.filter { $0.status == .completed || $0.status == .failed }.count + 1
        overallProgressMessage = "Processing file \(processed) of \(count): \(item.inputURL.lastPathComponent)"

        // Check FFmpeg
        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            failCurrentItem(message: "FFmpeg binary not found in Bundle.")
            return
        }
        
        // Determine Output URL
        guard let outDir = outputDirectory else {
            failCurrentItem(message: "Output directory lost.")
            return
        }
        
        let filename = item.inputURL.deletingPathExtension().lastPathComponent
        let outURL = outDir.appendingPathComponent(filename).appendingPathExtension(outputFormat.rawValue)
        
        fileQueue[index].outputURL = outURL

        // Build Command
        let args = commandBuilder.buildCommand(
            inputURL: item.inputURL,
            outputURL: outURL,
            outputFormat: outputFormat,
            videoCodec: videoCodec,
            videoQuality: videoQuality,
            audioCodec: audioCodec
        )

        // Run
        fileQueue[index].status = .converting
        processRunner.run(ffmpegPath: ffmpegPath, arguments: args, inputURL: item.inputURL)
    }

    func cancelBatch() {
        if isBatchConverting {
            processRunner.cancel() // Delegate will handle the failure state
            isBatchConverting = false
            overallProgressMessage = "Batch Cancelled"
            
            // Mark remaining pending as cancelled
            for i in 0..<fileQueue.count {
                if fileQueue[i].status == .pending {
                    fileQueue[i].status = .cancelled
                }
            }
        }
    }

    private func finishBatch() {
        isBatchConverting = false
        currentItemIndex = nil
        overallProgressMessage = "Batch Completed."
    }
    
    // MARK: - Helpers for Delegate
    
    private func failCurrentItem(message: String) {
        guard let index = currentItemIndex else { return }
        fileQueue[index].status = .failed
        fileQueue[index].errorMessage = message
        fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
        
        // Continue queue
        runBatchSequence()
    }
    
    private func completeCurrentItem() {
        guard let index = currentItemIndex else { return }
        fileQueue[index].status = .completed
        fileQueue[index].progress = 1.0
        fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
        
        // Calc Compression stats
        if let outURL = fileQueue[index].outputURL,
           let oldSize = FileUtilities.getFileSize(url: fileQueue[index].inputURL),
           let newSize = FileUtilities.getFileSize(url: outURL) {
            
            let oldStr = FileUtilities.formatBytes(oldSize)
            let newStr = FileUtilities.formatBytes(newSize)
            fileQueue[index].successMessage = "Done. \(oldStr) → \(newStr)"
        } else {
            fileQueue[index].successMessage = "Conversion successful."
        }

        // Continue queue
        runBatchSequence()
    }
}

// MARK: - Delegate Conformance
extension VideoConverter: FFmpegProcessRunnerDelegate {
    func processRunnerDidUpdateProgress(_ progress: Double) {
        guard let index = currentItemIndex else { return }
        fileQueue[index].progress = progress
    }

    func processRunnerDidFailWithError(_ error: String) {
        if error.contains("Cancelled") {
             guard let index = currentItemIndex else { return }
             fileQueue[index].status = .cancelled
             fileQueue[index].errorMessage = "Cancelled"
        } else {
            failCurrentItem(message: error)
        }
    }

    func processRunnerDidFinish() {
        completeCurrentItem()
    }
}
