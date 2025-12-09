import Foundation
import AVFoundation

class FFmpegProcessRunner {

    private var process: Process?
    private var outputPipe: Pipe?
    
    weak var delegate: FFmpegProcessRunnerDelegate?
    private var videoDuration: Double = 0.0
    private var userCancelled: Bool = false // Tracks if user clicked cancel
    
    // Compile Regex once
    private let progressRegex = try? NSRegularExpression(pattern: #"out_time_us=(\d+)"#)

    func run(ffmpegPath: String, arguments: [String], inputURL: URL) {
        self.videoDuration = 0.0
        self.userCancelled = false // Reset flag
        
        Task {
            let asset = AVURLAsset(url: inputURL)
            if let duration = try? await asset.load(.duration) {
                self.videoDuration = CMTimeGetSeconds(duration)
            }
            
            await MainActor.run {
                self.launchProcess(path: ffmpegPath, args: arguments)
            }
        }
    }

    private func launchProcess(path: String, args: [String]) {
        let task = Process()
        task.launchPath = path
        task.arguments = args
        
        let pipe = Pipe()
        task.standardOutput = pipe
        self.outputPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                self?.parseProgress(data: data)
            }
        }

        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleTermination(process)
            }
        }

        do {
            try task.run()
            self.process = task
        } catch {
            delegate?.processRunnerDidFailWithError("Failed to launch FFmpeg: \(error.localizedDescription)")
        }
    }

    private func parseProgress(data: Data) {
        guard let string = String(data: data, encoding: .utf8), videoDuration > 0 else { return }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        if let match = progressRegex?.firstMatch(in: string, options: [], range: range) {
            if let r = Range(match.range(at: 1), in: string),
               let us = Double(String(string[r])) {
                let seconds = us / 1_000_000.0
                let progress = min(max(seconds / videoDuration, 0.0), 1.0)
                
                DispatchQueue.main.async {
                    self.delegate?.processRunnerDidUpdateProgress(progress)
                }
            }
        }
    }

    private func handleTermination(_ process: Process) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        
        // CHECK FLAG FIRST: This guarantees we know it was a user action
        if userCancelled {
            delegate?.processRunnerDidFailWithError("Cancelled")
        }
        else if process.terminationStatus == 0 {
            delegate?.processRunnerDidFinish()
        } else {
            delegate?.processRunnerDidFailWithError("FFmpeg exited with code \(process.terminationStatus)")
        }
        self.process = nil
    }

    func cancel() {
        if let process = process, process.isRunning {
            userCancelled = true // Set flag immediately
            process.terminate()
        }
    }
}
