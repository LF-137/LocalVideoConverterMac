// MARK: - VideoConverter
// VideoConverter.swift (Revised)
import Foundation
import AVFoundation
import AppKit

class VideoConverter: ObservableObject {
    @Published var isConverting = false
    @Published var progress: Double = 0.0
    @Published var errorMessage: String? = nil

    private let commandBuilder = FFmpegCommandBuilder()
    private let processRunner = FFmpegProcessRunner()
    private var inputURLForSecurity: URL?

    init() {
        processRunner.delegate = self
    }

    func convertVideo(inputURL: URL, outputURL: URL, outputFormat: String, videoCodec: String, videoQuality: String, audioCodec: String) {
        isConverting = true
        progress = 0
        errorMessage = nil
        inputURLForSecurity = inputURL // Store for later

        guard inputURL.startAccessingSecurityScopedResource() else {
            self.errorMessage = "Unable to access security scoped resource."
            isConverting = false
            return
        }

        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            self.errorMessage = "FFmpeg not found in bundle."
            self.isConverting = false
            inputURL.stopAccessingSecurityScopedResource() // Stop accessing here
            return
        }

        let arguments = commandBuilder.buildCommand(inputURL: inputURL, outputURL: outputURL, outputFormat: outputFormat, videoCodec: videoCodec, videoQuality: videoQuality, audioCodec: audioCodec)

        processRunner.run(ffmpegPath: ffmpegPath, arguments: arguments, inputURL: inputURL)
    }

    func cancelConversion() {
        processRunner.cancel()
        inputURLForSecurity?.stopAccessingSecurityScopedResource()
        inputURLForSecurity = nil  // Clear the stored URL
        isConverting = false
        errorMessage = "Conversion cancelled."
    }
}
// MARK: - FFmpegProcessRunnerDelegate
extension VideoConverter: FFmpegProcessRunnerDelegate {
    func processRunnerDidUpdateProgress(_ progress: Double) {
        self.progress = progress
    }

    func processRunnerDidFailWithError(_ error: String) {
        inputURLForSecurity?.stopAccessingSecurityScopedResource()
        inputURLForSecurity = nil
        errorMessage = error
        isConverting = false
    }

    func processRunnerDidFinish() {
        inputURLForSecurity?.stopAccessingSecurityScopedResource()
        inputURLForSecurity = nil
        isConverting = false
    }
}
