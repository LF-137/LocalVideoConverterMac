
// MARK: - FFmpegProcessRunner
// FFmpegProcessRunner.swift
import Foundation
import AVFoundation
import AppKit

class FFmpegProcessRunner {

    private var process: Process?
    private var progressTimer: Timer?
    weak var delegate: FFmpegProcessRunnerDelegate?

    func run(ffmpegPath: String, arguments: [String], inputURL: URL) {
        let task = Process()
        self.process = task
        task.launchPath = ffmpegPath
        task.arguments = arguments
        print("FFmpeg Arguments: \(arguments)")

        let errorPipe = Pipe()
        task.standardError = errorPipe
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        let duration = self.getVideoDuration(inputURL)
        self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let errorData = errorPipe.fileHandleForReading.availableData
           if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8) {

               if let timeRange = errorString.range(of: "time=(\\d+:\\d+:\\d+(?:\\.\\d+)?)", options: .regularExpression) {
                   let timeString = String(errorString[timeRange].dropFirst(5))
                   let currentTimeInSeconds = self.timeStringToSeconds(timeString)
                   let calculatedProgress = duration > 0 ? min(1.0, currentTimeInSeconds / duration) : 0.0

                    self.delegate?.processRunnerDidUpdateProgress(calculatedProgress)
               }
           }
        }
        RunLoop.current.add(self.progressTimer!, forMode: .common)

        task.terminationHandler = { [weak self] process in
             DispatchQueue.main.async {
                self?.progressTimer?.invalidate()
                self?.progressTimer = nil
                self?.process = nil

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

                if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                    self?.delegate?.processRunnerDidFailWithError("FFmpeg error: \(errorString)")
                } else if process.terminationStatus != 0 {
                    self?.delegate?.processRunnerDidFailWithError("FFmpeg failed with exit code: \(process.terminationStatus)")
                } else {
                    self?.delegate?.processRunnerDidFinish()
                }
                if let outputString = String(data: outputData, encoding: .utf8), !outputString.isEmpty {
                       print("FFmpeg Standard Output: \(outputString)")
                   }
             }
        }

        do {
            try task.run()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.processRunnerDidFailWithError("Failed to start FFmpeg: \(error)")
            }
        }
    }

    func timeStringToSeconds(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    func getVideoDuration(_ url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        return Double(asset.duration.value) / Double(asset.duration.timescale)
    }

    func cancel() {
        progressTimer?.invalidate()
        progressTimer = nil
        process?.terminate()
        process = nil
    }
}
