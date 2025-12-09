import Foundation
import Combine
import AVFoundation
import AppKit
import UserNotifications

@MainActor
class VideoConverter: ObservableObject {

    // MARK: - Published Properties
    @Published var fileQueue: [FileQueueItem] = []
    @Published var isBatchConverting: Bool = false
    @Published var overallProgressMessage: String = ""
    @Published var globalErrorMessage: String? = nil
    
    @Published var mode: ConversionMode = .videoConversion
    
    @Published var outputFormat: OutputFormat = .mp4
    @Published var videoQuality: VideoQuality = .medium
    @Published var audioCodec: AudioCodec = .aac
    @Published var videoCodec: VideoCodec = .h264
    @Published var audioExportFormat: AudioExportFormat = .mp3
    
    // NEW: Store the selected engine
    @Published var encodingType: EncodingType = .hardware

    // MARK: - Internal State
    private let commandBuilder = FFmpegCommandBuilder()
    private let processRunner = FFmpegProcessRunner()
    private var currentItemIndex: Int? = nil
    private var outputDirectory: URL? = nil
    
    // Timer Logic
    private var currentItemStartTime: Date? = nil
    private var timer: Timer?
    
    private var pendingSubTasks: [[String]] = []
    private var currentSubTaskTotal = 1
    private var currentSubTaskIndex = 0
    private var currentActiveOutputURLs: [URL] = []

    init() {
        processRunner.delegate = self
    }

    // MARK: - Queue Management
    
    func addFiles(urls: [URL]) {
        self.globalErrorMessage = nil
        
        for url in urls {
            if fileQueue.contains(where: { $0.inputURL.path == url.path }) {
                print("Skipping duplicate: \(url.lastPathComponent)")
                continue
            }

            var scopedURL = url
            let isScoped = url.startAccessingSecurityScopedResource()
            if !isScoped { print("Warning: Access denied for \(url.lastPathComponent)") }
            
            let item = FileQueueItem(
                inputURL: url,
                securityScopedInputURL: isScoped ? scopedURL : nil,
                status: .analyzing
            )
            
            let newIndex = fileQueue.count
            fileQueue.append(item)
            
            Task {
                let tracks = await analyzeAudioTracks(for: url)
                if newIndex < self.fileQueue.count && self.fileQueue[newIndex].id == item.id {
                    self.fileQueue[newIndex].audioTracks = tracks
                    self.fileQueue[newIndex].status = .pending
                    
                    if !tracks.isEmpty {
                        self.fileQueue[newIndex].audioTracks[0].isSelected = true
                        self.fileQueue[newIndex].audioTracks[0].customName = url.deletingPathExtension().lastPathComponent + " - Track 1"
                    }
                }
            }
        }
    }
    
    func moveItems(from source: IndexSet, to destination: Int) {
        fileQueue.move(fromOffsets: source, toOffset: destination)
    }
    
    private func analyzeAudioTracks(for url: URL) async -> [AudioTrackInfo] {
        let asset = AVURLAsset(url: url)
        var infos: [AudioTrackInfo] = []
        
        do {
            let tracks = try await asset.load(.tracks)
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            
            for (index, _) in audioTracks.enumerated() {
                let title = "Track \(index + 1)"
                infos.append(AudioTrackInfo(index: index, language: "Unknown", title: title))
            }
        } catch {
            print("Error analyzing tracks: \(error)")
        }
        return infos
    }

    func clearQueue() {
        cancelBatch()
        fileQueue.forEach { $0.securityScopedInputURL?.stopAccessingSecurityScopedResource() }
        fileQueue.removeAll()
        globalErrorMessage = nil
        overallProgressMessage = ""
    }

    func removeItems(at offsets: IndexSet) {
        offsets.forEach { index in
            fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
            if index == currentItemIndex { cancelBatch() }
        }
        fileQueue.remove(atOffsets: offsets)
        if fileQueue.isEmpty { isBatchConverting = false; currentItemIndex = nil }
    }
    
    // MARK: - Helper Update Methods
    
    func toggleTrackSelection(itemID: UUID, trackID: UUID) {
        guard let itemIndex = fileQueue.firstIndex(where: { $0.id == itemID }),
              let trackIndex = fileQueue[itemIndex].audioTracks.firstIndex(where: { $0.id == trackID }) else { return }
        
        fileQueue[itemIndex].audioTracks[trackIndex].isSelected.toggle()
        
        if fileQueue[itemIndex].audioTracks[trackIndex].isSelected && fileQueue[itemIndex].audioTracks[trackIndex].customName.isEmpty {
            let base = fileQueue[itemIndex].inputURL.deletingPathExtension().lastPathComponent
            fileQueue[itemIndex].audioTracks[trackIndex].customName = "\(base) - Track \(fileQueue[itemIndex].audioTracks[trackIndex].index + 1)"
        }
    }
    
    func updateTrackName(itemID: UUID, trackID: UUID, newName: String) {
        guard let itemIndex = fileQueue.firstIndex(where: { $0.id == itemID }),
              let trackIndex = fileQueue[itemIndex].audioTracks.firstIndex(where: { $0.id == trackID }) else { return }
        fileQueue[itemIndex].audioTracks[trackIndex].customName = newName
    }
    
    func toggleMerge(itemID: UUID) {
        guard let idx = fileQueue.firstIndex(where: { $0.id == itemID }) else { return }
        fileQueue[idx].mergeSelectedTracks.toggle()
        if fileQueue[idx].mergeSelectedTracks && fileQueue[idx].mergedTrackName.isEmpty {
            fileQueue[idx].mergedTrackName = fileQueue[idx].inputURL.deletingPathExtension().lastPathComponent + " - Merged"
        }
    }
    
    func updateMergedName(itemID: UUID, name: String) {
        guard let idx = fileQueue.firstIndex(where: { $0.id == itemID }) else { return }
        fileQueue[idx].mergedTrackName = name
    }

    // MARK: - Batch Processing

    func startBatch() {
        guard !fileQueue.isEmpty else { return }
        
        if mode == .audioExtraction {
            let anyWork = fileQueue.contains { $0.hasWorkToDo }
            if !anyWork {
                globalErrorMessage = "Please select at least one audio track to extract."
                return
            }
        }
        
        FileUtilities.chooseOutputDirectory { [weak self] url in
            guard let self = self, let url = url else { return }
            self.outputDirectory = url
            self.runBatchSequence()
        }
    }

    private func runBatchSequence() {
        isBatchConverting = true
        globalErrorMessage = nil
        
        guard let index = fileQueue.firstIndex(where: { $0.status == .pending }) else {
            finishBatch()
            return
        }
        
        startConversion(at: index)
    }

    private func startConversion(at index: Int) {
        currentItemIndex = index
        currentItemStartTime = Date()
        pendingSubTasks = []
        currentActiveOutputURLs = []
        
        // Start the UI Timer
        startTimer()
        
        fileQueue[index].status = .preparing
        fileQueue[index].errorMessage = nil
        fileQueue[index].elapsedTime = "00:00"
        
        let item = fileQueue[index]
        
        let count = fileQueue.count
        let processed = fileQueue.filter { $0.status == .completed || $0.status == .failed }.count + 1
        overallProgressMessage = "Processing file \(processed) of \(count): \(item.inputURL.lastPathComponent)"

        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            failCurrentItem(message: "FFmpeg binary not found."); return
        }
        guard let outDir = outputDirectory else {
            failCurrentItem(message: "Output directory lost."); return
        }
        
        if mode == .videoConversion {
            let originalFilename = item.inputURL.deletingPathExtension().lastPathComponent
            let idealURL = outDir.appendingPathComponent(originalFilename).appendingPathExtension(outputFormat.rawValue)
            let uniqueURL = FileUtilities.generateUniqueOutputPath(from: idealURL)
            
            fileQueue[index].outputURL = uniqueURL
            currentActiveOutputURLs.append(uniqueURL)
            
            // UPDATED: Pass the encodingType here
            let args = commandBuilder.buildVideoCommand(
                inputURL: item.inputURL,
                outputURL: uniqueURL,
                outputFormat: outputFormat,
                videoCodec: videoCodec,
                videoQuality: videoQuality,
                audioCodec: audioCodec,
                encodingType: encodingType // <--- Using the state variable
            )
            
            print("🚀 Running FFmpeg Command: \(args.joined(separator: " "))")
            pendingSubTasks.append(args)
            
        } else {
            for track in item.audioTracks where track.isSelected {
                let name = track.customName.isEmpty ? "Track \(track.index)" : track.customName
                let idealURL = outDir.appendingPathComponent(name).appendingPathExtension(audioExportFormat.extensionName)
                let uniqueURL = FileUtilities.generateUniqueOutputPath(from: idealURL)
                
                currentActiveOutputURLs.append(uniqueURL)
                
                let args = commandBuilder.buildSingleTrackExtraction(
                    inputURL: item.inputURL,
                    outputURL: uniqueURL,
                    trackIndex: track.index,
                    format: audioExportFormat
                )
                pendingSubTasks.append(args)
            }
            
            if item.mergeSelectedTracks {
                let selectedIndices = item.audioTracks.filter { $0.isSelected }.map { $0.index }
                if selectedIndices.count > 1 {
                    let name = item.mergedTrackName.isEmpty ? "Merged" : item.mergedTrackName
                    let idealURL = outDir.appendingPathComponent(name).appendingPathExtension(audioExportFormat.extensionName)
                    let uniqueURL = FileUtilities.generateUniqueOutputPath(from: idealURL)
                    
                    currentActiveOutputURLs.append(uniqueURL)
                    
                    let args = commandBuilder.buildMergedAudioCommand(
                        inputURL: item.inputURL,
                        outputURL: uniqueURL,
                        trackIndices: selectedIndices,
                        format: audioExportFormat
                    )
                    pendingSubTasks.append(args)
                }
            }
        }
        
        if pendingSubTasks.isEmpty {
            failCurrentItem(message: "No tasks generated.")
            return
        }
        
        currentSubTaskTotal = pendingSubTasks.count
        currentSubTaskIndex = 0
        runNextSubTask(ffmpegPath: ffmpegPath)
    }
    
    private func runNextSubTask(ffmpegPath: String) {
        guard let index = currentItemIndex else { return }
        
        if currentSubTaskIndex < pendingSubTasks.count {
            fileQueue[index].status = .converting
            let args = pendingSubTasks[currentSubTaskIndex]
            
            if currentSubTaskTotal > 1 {
                overallProgressMessage = "Processing item \(index + 1) (Task \(currentSubTaskIndex + 1)/\(currentSubTaskTotal))..."
            }
            
            processRunner.run(ffmpegPath: ffmpegPath, arguments: args, inputURL: fileQueue[index].inputURL)
        } else {
            completeCurrentItem()
        }
    }

    func cancelBatch() {
        if isBatchConverting {
            stopTimer()
            processRunner.cancel()
            isBatchConverting = false
            overallProgressMessage = "Batch Cancelled"
            for i in 0..<fileQueue.count {
                if fileQueue[i].status == .pending { fileQueue[i].status = .cancelled }
            }
        }
    }

    private func finishBatch() {
        stopTimer()
        isBatchConverting = false
        currentItemIndex = nil
        overallProgressMessage = "Batch Completed."
        sendNotification()
    }
    
    // MARK: - Timer Logic
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTimerUI()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimerUI() {
        guard let index = currentItemIndex,
              let start = currentItemStartTime,
              index < fileQueue.count else { return }
        
        let elapsed = Date().timeIntervalSince(start)
        let s = Int(elapsed) % 60
        let m = (Int(elapsed) / 60) % 60
        let h = Int(elapsed) / 3600
        
        if h > 0 {
            fileQueue[index].elapsedTime = String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            fileQueue[index].elapsedTime = String(format: "%02d:%02d", m, s)
        }
    }
    
    // MARK: - Helpers
    
    private func cleanupPartialFiles(at index: Int) {
        let urlsToClean = currentActiveOutputURLs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for url in urlsToClean {
                if FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                    print("✅ Successfully removed partial file: \(url.lastPathComponent)")
                }
            }
        }
    }
    
    func revealInFinder(item: FileQueueItem) {
        if let url = item.outputURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            if let directory = outputDirectory {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
            }
        }
    }
    
    private func sendNotification() {
        NotificationManager.shared.sendCompletionNotification()
    }
    
    private func formatDuration(_ start: Date) -> String {
        let duration = Date().timeIntervalSince(start)
        let totalSeconds = Int(duration)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 { return "\(h)h \(m)m \(s)s" }
        else if m > 0 { return "\(m)m \(s)s" }
        else { return "\(s)s" }
    }
    
    private func failCurrentItem(message: String) {
        guard let index = currentItemIndex else { return }
        stopTimer()
        cleanupPartialFiles(at: index)
        fileQueue[index].status = .failed
        fileQueue[index].errorMessage = message
        fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
        runBatchSequence()
    }
    
    private func completeCurrentItem() {
        guard let index = currentItemIndex else { return }
        stopTimer()
        fileQueue[index].status = .completed
        fileQueue[index].progress = 1.0
        fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
        
        let durationStr = (currentItemStartTime != nil) ? formatDuration(currentItemStartTime!) : ""
        
        var sizeInfo = ""
        let inputSize = FileUtilities.getFileSize(url: fileQueue[index].inputURL)
        
        if let outURL = fileQueue[index].outputURL,
           let oldSize = inputSize,
           let newSize = FileUtilities.getFileSize(url: outURL) {
            
            let oldStr = FileUtilities.formatBytes(oldSize)
            let newStr = FileUtilities.formatBytes(newSize)
            sizeInfo = "\(oldStr) → \(newStr)"
        }
        
        if sizeInfo.isEmpty {
             fileQueue[index].successMessage = "Done (\(durationStr))"
        } else {
             fileQueue[index].successMessage = "Done (\(durationStr)) • \(sizeInfo)"
        }
        
        runBatchSequence()
    }
}

extension VideoConverter: FFmpegProcessRunnerDelegate {
    func processRunnerDidUpdateProgress(_ progress: Double) {
        guard let index = currentItemIndex else { return }
        let taskWeight = 1.0 / Double(currentSubTaskTotal)
        let currentBase = Double(currentSubTaskIndex) * taskWeight
        let actualProgress = currentBase + (progress * taskWeight)
        fileQueue[index].progress = actualProgress
    }

    func processRunnerDidFailWithError(_ error: String) {
        if error.contains("Cancelled") {
             guard let index = currentItemIndex else { return }
             stopTimer()
             cleanupPartialFiles(at: index)
             fileQueue[index].status = .cancelled; fileQueue[index].errorMessage = "Cancelled"
             fileQueue[index].securityScopedInputURL?.stopAccessingSecurityScopedResource()
        } else {
            failCurrentItem(message: error)
        }
    }

    func processRunnerDidFinish() {
        currentSubTaskIndex += 1
        if let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            runNextSubTask(ffmpegPath: ffmpegPath)
        }
    }
}
