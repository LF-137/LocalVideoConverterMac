import Foundation
import AVFoundation

class FFmpegProcessRunner {

    private var process: Process?
    private var outputPipe: Pipe?
    
    weak var delegate: FFmpegProcessRunnerDelegate?
    private var videoDuration: Double = 0.0
    
    // Compile Regex once for performance
    private let progressRegex = try? NSRegularExpression(pattern: #"out_time_us=(\d+)"#)

    func run(ffmpegPath: String, arguments: [String], inputURL: URL) {
        // Reset state
        self.videoDuration = 0.0
        
        // 1. Get Duration Asynchronously
        Task {
            let asset = AVURLAsset(url: inputURL)
            if let duration = try? await asset.load(.duration) {
                self.videoDuration = CMTimeGetSeconds(duration)
            }
            
            // 2. Start Process on Main Thread (safe for Process object) to launch
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
        
        // We don't strictly need stderr for progress, but good for debug if needed
        // task.standardError = Pipe()

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
        
        // Simple string parsing is often faster than regex for high frequency logs,
        // but regex is robust.
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
        
        if process.terminationStatus == 0 {
            delegate?.processRunnerDidFinish()
        } else {
            // 15 = SIGTERM (Cancelled)
            if process.terminationStatus == 15 {
                delegate?.processRunnerDidFailWithError("Cancelled by user")
            } else {
                delegate?.processRunnerDidFailWithError("FFmpeg exited with code \(process.terminationStatus)")
            }
        }
        self.process = nil
    }

    func cancel() {
        if let process = process, process.isRunning {
            process.terminate()
        }
    }
}
