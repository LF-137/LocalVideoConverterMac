import Foundation
import AVFoundation
import AppKit

class VideoConverter: ObservableObject {
    // MARK: - Published Properties

    /// Published property to track if a video conversion is currently in progress.
    /// UI elements can observe this to show progress indicators or disable controls.
    @Published var isConverting = false

    /// Published property to report the conversion progress (0.0 to 1.0).
    /// ProgressView in ContentView observes this to update the UI.
    @Published var progress: Double = 0.0

    /// Published property to hold any error message that occurs during conversion.
    /// ContentView observes this to display error messages to the user.
    @Published var errorMessage: String? = nil


    // MARK: - Private Properties

    /// Instance of FFmpegCommandBuilder to construct FFmpeg command-line arguments.
    private let commandBuilder = FFmpegCommandBuilder()

    /// Instance of FFmpegProcessRunner to execute FFmpeg commands.
    private let processRunner = FFmpegProcessRunner()

    /// Stores the input video URL for security-scoped resource access.
    /// This is needed to stop accessing the resource when conversion is finished or cancelled.
    private var inputURLForSecurity: URL?


    // MARK: - Initializer

    init() {
        processRunner.delegate = self // Set VideoConverter as delegate for processRunner callbacks.
    }


    // MARK: - Conversion Functions

    /// Initiates the video conversion process.
    func convertVideo(inputURL: URL, outputURL: URL, outputFormat: String, videoCodec: String, videoQuality: String, audioCodec: String) {
        isConverting = true    // Set conversion state to true
        progress = 0          // Reset progress
        errorMessage = nil     // Clear previous error
        inputURLForSecurity = inputURL // Store input URL for security access

        guard inputURL.startAccessingSecurityScopedResource() else { // Start accessing security-scoped resource
            self.errorMessage = "Unable to access security scoped resource."
            isConverting = false
            return // Exit if security access fails
        }

        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else { // Locate FFmpeg executable
            self.errorMessage = "FFmpeg not found in bundle."
            self.isConverting = false
            inputURL.stopAccessingSecurityScopedResource() // Stop accessing resource on failure
            return // Exit if FFmpeg not found
        }

        let arguments = commandBuilder.buildCommand( // Build FFmpeg command arguments
            inputURL: inputURL, outputURL: outputURL, outputFormat: outputFormat,
            videoCodec: videoCodec, videoQuality: videoQuality, audioCodec: audioCodec
        )

        processRunner.run(ffmpegPath: ffmpegPath, arguments: arguments, inputURL: inputURL) // Run FFmpeg process
    }


    /// Cancels the currently running video conversion.
    func cancelConversion() {
        processRunner.cancel() // Cancel FFmpeg process
        inputURLForSecurity?.stopAccessingSecurityScopedResource() // Stop security-scoped resource access
        inputURLForSecurity = nil  // Clear stored input URL
        isConverting = false       // Reset conversion state
        errorMessage = "Conversion cancelled." // Set cancellation message
    }
}


// MARK: - FFmpegProcessRunnerDelegate Extension

extension VideoConverter: FFmpegProcessRunnerDelegate {
    /// Delegate callback: Updates conversion progress.
    func processRunnerDidUpdateProgress(_ progress: Double) {
        DispatchQueue.main.async { [weak self] in // Use [weak self] to avoid retain cycle
            self?.progress = progress // Update progress on main thread
        }
    }


    /// Delegate callback: Handles FFmpeg process failure.
    func processRunnerDidFailWithError(_ error: String) {
        DispatchQueue.main.async { [weak self] in // Use [weak self] to avoid retain cycle
            self?.inputURLForSecurity?.stopAccessingSecurityScopedResource() // Stop security-scoped access
            self?.inputURLForSecurity = nil // Clear stored input URL
            self?.errorMessage = error       // Set error message
            self?.isConverting = false    // Reset conversion state
        }
    }


    /// Delegate callback: Handles successful FFmpeg process finish.
    func processRunnerDidFinish() {
        DispatchQueue.main.async { [weak self] in // Use [weak self] to avoid retain cycle
            self?.inputURLForSecurity?.stopAccessingSecurityScopedResource() // Stop security-scoped access
            self?.inputURLForSecurity = nil // Clear stored input URL
            self?.isConverting = false    // Reset conversion state
        }
    }
}
