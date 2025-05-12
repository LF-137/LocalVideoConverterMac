import Foundation
import AVFoundation // Keep for duration calculation if needed within ViewModel
import AppKit // Keep for NSApplication delegate interaction if needed later

/// ObservableObject acting as the ViewModel for video conversion.
/// Manages conversion state, settings, interaction with `FFmpegProcessRunner`,
/// and provides published properties for the SwiftUI View (`ContentView`).
class VideoConverter: ObservableObject {

    // MARK: - Published Properties for UI Binding

    /// The URL of the input video file selected by the user.
    @Published var inputURL: URL? = nil {
        didSet { // Clear messages when input changes
            clearMessages()
            // Automatically determine a default output URL when input changes
            updateDefaultOutputURL()
        }
    }
    /// The automatically suggested URL for the output file.
    @Published var defaultOutputURL: URL? = nil

    /// Indicates if a conversion is currently active.
    @Published var isConverting = false
    /// Current conversion progress (0.0 to 1.0).
    @Published var progress: Double = 0.0
    /// Holds the latest error message for display.
    @Published var errorMessage: String? = nil
    /// Holds the latest success message for display.
    @Published var successMessage: String? = nil

    // MARK: - Published Settings (Bound from SettingsView)

    /// Selected output container format (e.g., "mp4", "mov").
    @Published var outputFormat = "mp4" { didSet { updateDefaultOutputURL() } }
    /// Selected video quality preset ("high", "medium", "low").
    @Published var videoQuality = "medium"
    /// Selected audio codec ("aac", "mp3", "none").
    @Published var audioCodec = "aac"
    /// Selected video codec ("h264", "hevc").
    @Published var videoCodec = "h264"

    // MARK: - Private Properties

    /// Service responsible for building FFmpeg commands.
    private let commandBuilder = FFmpegCommandBuilder()
    /// Service responsible for running FFmpeg processes.
    private let processRunner = FFmpegProcessRunner()
    /// Stores the input URL specifically for managing security-scoped access.
    private var securityScopedInputURL: URL? = nil

    // MARK: - Initialization

    init() {
        // Set self as the delegate to receive callbacks from the process runner.
        processRunner.delegate = self
        print("VideoConverter initialized. ProcessRunner delegate set.")
    }

    // MARK: - Public Methods for UI Interaction

    /// Sets the input video URL, ensuring it's a valid video file.
    /// - Parameter url: The URL selected or dropped by the user.
    func setInputURL(_ url: URL?) {
        DispatchQueue.main.async { // Ensure UI updates happen on main thread
            guard let url = url else {
                self.inputURL = nil
                return
            }

            // Validate if it's a video file *before* assigning
            if FileUtilities.isVideoFile(url) {
                self.inputURL = url
                // Note: Security scope access is started in FileUtilities.selectFile
                // or should be started here if handling drops required it *before* validation.
                // For now, assume selectFile handled it, or conversion will start it.
            } else {
                self.inputURL = nil
                self.errorMessage = "'\(url.lastPathComponent)' is not recognized as a valid video file."
            }
        }
    }

    /// Clears the current input selection and related messages.
    func clearInput() {
        DispatchQueue.main.async {
            // Stop security access if we were holding onto it from a previous selection
            self.stopSecurityAccess()
            self.inputURL = nil
            self.clearMessages()
            print("Input cleared.")
        }
    }

    /// Initiates the video conversion process using the current settings.
    func startConversion() {
        clearMessages()

        guard let currentInputURL = inputURL else {
            errorMessage = "No input video selected."
            return
        }

        // Ensure we have security access before proceeding
        guard startSecurityAccess(url: currentInputURL) else {
            errorMessage = "Could not get permission to access the input video file. Please select it again."
            return
        }

        // Choose output location
        guard let outputURL = FileUtilities.chooseOutputURL(defaultURL: defaultOutputURL ?? currentInputURL, selectedFormat: outputFormat) else {
            // User cancelled save panel
            print("User cancelled output selection.")
            // Stop access if we started it just for this attempt
            stopSecurityAccess()
            return
        }

        // Find FFmpeg executable
        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            errorMessage = "Critical Error: FFmpeg executable not found in the app bundle."
            stopSecurityAccess()
            return
        }

        // Build the command
        let arguments = commandBuilder.buildCommand(
            inputURL: currentInputURL,
            outputURL: outputURL,
            outputFormat: outputFormat,
            videoCodec: videoCodec,
            videoQuality: videoQuality,
            audioCodec: audioCodec
        )

        // Update state before starting
        DispatchQueue.main.async {
            self.isConverting = true
            self.progress = 0.0
            print("Starting conversion: \(currentInputURL.lastPathComponent) -> \(outputURL.lastPathComponent)")
            // Run the process (will happen on a background thread managed by ProcessRunner)
            self.processRunner.run(ffmpegPath: ffmpegPath, arguments: arguments, inputURL: currentInputURL)
        }
    }

    /// Cancels the currently running video conversion.
    func cancelConversion() {
        print("Cancel requested by user.")
        processRunner.cancel() // Ask the runner to cancel the process

        // State update and cleanup happens via the delegate callback (processRunnerDidFailWithError or processRunnerDidFinish)
        // But we can set a preliminary message and state here.
        DispatchQueue.main.async {
            if self.isConverting { // Only set cancelled message if it was actually running
                 self.errorMessage = "Conversion cancelled by user."
                 self.isConverting = false // Force immediate UI update if needed
                 self.progress = 0.0
                 self.stopSecurityAccess() // Ensure access is stopped on explicit cancel
            }
        }
    }

    // MARK: - Private Helper Methods

    /// Updates the default output URL based on the current input URL and format.
    private func updateDefaultOutputURL() {
        guard let input = inputURL else {
            defaultOutputURL = nil
            return
        }
        // Suggest same directory, same name, new extension
        defaultOutputURL = input.deletingPathExtension().appendingPathExtension(outputFormat)
    }

    /// Clears any existing error or success messages.
    private func clearMessages() {
        if errorMessage != nil || successMessage != nil {
             DispatchQueue.main.async {
                 self.errorMessage = nil
                 self.successMessage = nil
             }
        }
    }

    /// Starts security-scoped resource access for the given URL.
    /// Stores the URL if access is successful.
    /// - Parameter url: The URL requiring access.
    /// - Returns: `true` if access was successful or already active, `false` otherwise.
    private func startSecurityAccess(url: URL) -> Bool {
        // If we are already accessing this URL, no need to start again
        if securityScopedInputURL == url {
            return true
        }
        // Stop access to any previous URL
        stopSecurityAccess()

        // Try to start access for the new URL
        if url.startAccessingSecurityScopedResource() {
            securityScopedInputURL = url // Store it so we can stop later
            print("Started security access for: \(url.lastPathComponent)")
            return true
        } else {
            print("Failed to start security access for: \(url.lastPathComponent)")
            securityScopedInputURL = nil
            return false
        }
    }

    /// Stops security-scoped resource access for the stored URL.
    private func stopSecurityAccess() {
        if let url = securityScopedInputURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedInputURL = nil // Clear the stored URL
            print("Stopped security access for: \(url.lastPathComponent)")
        }
    }

    /// Common cleanup logic called after conversion finishes or fails.
    private func conversionDidEnd() {
        stopSecurityAccess()
        isConverting = false
        progress = 0.0 // Reset progress
    }
}

// MARK: - FFmpegProcessRunnerDelegate Extension

extension VideoConverter: FFmpegProcessRunnerDelegate {

    /// Called by `FFmpegProcessRunner` when conversion progress updates.
    func processRunnerDidUpdateProgress(_ progress: Double) {
        // Update happens frequently, ensure it's lightweight
        DispatchQueue.main.async {
            // Clamp progress between 0 and 1
            self.progress = min(max(0.0, progress), 1.0)
        }
    }

    /// Called by `FFmpegProcessRunner` when the conversion process fails.
    func processRunnerDidFailWithError(_ error: String) {
        print("Delegate received error: \(error)")
        DispatchQueue.main.async {
            // Check if the error is due to cancellation to avoid overwriting user message
            if self.errorMessage == nil || !self.errorMessage!.contains("cancelled") {
                 self.errorMessage = "Conversion Failed: \(error)"
            }
            self.conversionDidEnd() // Perform common cleanup
        }
    }

    /// Called by `FFmpegProcessRunner` when the conversion process finishes successfully.
    func processRunnerDidFinish() {
        print("Delegate received finish.")
        DispatchQueue.main.async {
            self.successMessage = "Conversion completed successfully!"
            self.conversionDidEnd() // Perform common cleanup
            // Optionally, clear the input URL after successful conversion
             // self.inputURL = nil
        }
    }
}
