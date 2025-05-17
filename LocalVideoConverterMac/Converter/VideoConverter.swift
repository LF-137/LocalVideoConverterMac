import Foundation
import AVFoundation
import AppKit

class VideoConverter: ObservableObject {

    // MARK: - Published Properties for UI Binding
    @Published var inputURL: URL? = nil {
        didSet {
            clearMessages()
            updateDefaultOutputURL()
        }
    }
    @Published var defaultOutputURL: URL? = nil
    @Published var isConverting = false
    @Published var progress: Double = 0.0
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    // MARK: - Published Settings
    @Published var outputFormat: OutputFormat = .mp4 { didSet { updateDefaultOutputURL() } }
    @Published var videoQuality: VideoQuality = .medium
    @Published var audioCodec: AudioCodec = .aac
    @Published var videoCodec: VideoCodec = .h264

    // MARK: - Private Properties
    private let commandBuilder = FFmpegCommandBuilder()
    private let processRunner = FFmpegProcessRunner()
    private var securityScopedInputURL: URL? = nil
    private var currentOutputURL: URL? = nil // To store the output URL during conversion

    // MARK: - Initialization
    init() {
        processRunner.delegate = self
        print("VideoConverter initialized. ProcessRunner delegate set.")
    }

    // MARK: - Public Methods for UI Interaction
    func setInputURL(_ url: URL?) {
        DispatchQueue.main.async {
            guard let url = url else {
                self.inputURL = nil
                return
            }
            if FileUtilities.isVideoFile(url) {
                self.inputURL = url
            } else {
                self.inputURL = nil
                self.errorMessage = "'\(url.lastPathComponent)' is not recognized as a valid video file."
            }
        }
    }

    func clearInput() {
        DispatchQueue.main.async {
            self.stopSecurityAccess()
            self.inputURL = nil
            self.currentOutputURL = nil // Clear stored output URL as well
            self.clearMessages()
            print("Input cleared.")
        }
    }

    func startConversion() {
        clearMessages()

        guard let currentInputURL = inputURL else {
            errorMessage = "No input video selected."
            return
        }

        guard startSecurityAccess(url: currentInputURL) else {
            errorMessage = "Could not get permission to access the input video file. Please select it again."
            return
        }

        guard let chosenOutputURL = FileUtilities.chooseOutputURL(defaultURL: defaultOutputURL ?? currentInputURL, selectedFormat: outputFormat.rawValue) else {
            print("User cancelled output selection.")
            stopSecurityAccess() // Stop access if we started it for this attempt
            return
        }
        self.currentOutputURL = chosenOutputURL // Store the chosen output URL

        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            errorMessage = "Critical Error: FFmpeg executable not found in the app bundle."
            self.currentOutputURL = nil // Clear if we can't proceed
            stopSecurityAccess()
            return
        }

        let arguments = commandBuilder.buildCommand(
            inputURL: currentInputURL,
            outputURL: chosenOutputURL, // Use the chosen output URL
            outputFormat: outputFormat,
            videoCodec: videoCodec,
            videoQuality: videoQuality,
            audioCodec: audioCodec
        )

        DispatchQueue.main.async {
            self.isConverting = true
            self.progress = 0.0
            print("Starting conversion: \(currentInputURL.lastPathComponent) -> \(chosenOutputURL.lastPathComponent)")
            self.processRunner.run(ffmpegPath: ffmpegPath, arguments: arguments, inputURL: currentInputURL)
        }
    }

    func cancelConversion() {
        print("Cancel requested by user.")
        processRunner.cancel()

        DispatchQueue.main.async {
            if self.isConverting {
                 self.errorMessage = "Conversion cancelled by user."
                 // Let conversionDidEnd handle state changes, called by the delegate
            }
        }
    }

    // MARK: - Private Helper Methods
    private func updateDefaultOutputURL() {
        guard let input = inputURL else {
            defaultOutputURL = nil
            return
        }
        defaultOutputURL = input.deletingPathExtension().appendingPathExtension(outputFormat.rawValue)
    }

    private func clearMessages() {
        if errorMessage != nil || successMessage != nil {
             DispatchQueue.main.async {
                 self.errorMessage = nil
                 self.successMessage = nil
             }
        }
    }

    private func startSecurityAccess(url: URL) -> Bool {
        if securityScopedInputURL == url {
            // Already accessing, or it's the same URL and startAccessingSecurityScopedResource is idempotent
            // Check if we can still access it (e.g., bookmark not stale)
            // For simplicity, we re-attempt if it's not literally the same securityScopedInputURL instance
            // or if we don't have one.
            if url.startAccessingSecurityScopedResource() {
                 if securityScopedInputURL != url { // If it was a different URL before or nil
                     // Stop previous one if any
                     securityScopedInputURL?.stopAccessingSecurityScopedResource()
                     securityScopedInputURL = url
                 }
                 print("Security access confirmed/re-established for: \(url.lastPathComponent)")
                 return true
            } else {
                 print("Failed to re-establish security access for: \(url.lastPathComponent)")
                 securityScopedInputURL = nil // Clear if access failed
                 return false
            }
        }
        
        // Stop access to any previous URL if it's different
        stopSecurityAccess()

        if url.startAccessingSecurityScopedResource() {
            securityScopedInputURL = url
            print("Started security access for: \(url.lastPathComponent)")
            return true
        } else {
            print("Failed to start security access for: \(url.lastPathComponent)")
            securityScopedInputURL = nil
            return false
        }
    }

    private func stopSecurityAccess() {
        if let url = securityScopedInputURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedInputURL = nil
            print("Stopped security access for: \(url.lastPathComponent)")
        }
    }

    private func conversionDidEnd() {
        stopSecurityAccess() // This handles the input file's security scope
        // Output file (currentOutputURL) doesn't need explicit security scope stopping
        // as it was created by the app in a user-chosen location.
        isConverting = false
        progress = 0.0
        // Don't clear currentOutputURL here, as processRunnerDidFinish might still need it briefly
        // It will be cleared on next clearInput or new conversion start.
    }
}

// MARK: - FFmpegProcessRunnerDelegate Extension
extension VideoConverter: FFmpegProcessRunnerDelegate {

    func processRunnerDidUpdateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progress = min(max(0.0, progress), 1.0)
        }
    }

    func processRunnerDidFailWithError(_ error: String) {
        print("Delegate received error: \(error)")
        DispatchQueue.main.async {
            // Check if the error is due to cancellation to avoid overwriting user message
            // This check is tricky if cancelConversion sets the message first.
            // The delegate might arrive slightly later.
            if self.errorMessage == nil || !self.errorMessage!.contains("cancelled by user") {
                 self.errorMessage = "Conversion Failed: \(error)"
            }
            self.conversionDidEnd()
            self.currentOutputURL = nil // Clear after failure
        }
    }

    func processRunnerDidFinish() {
        print("Delegate received finish.")
        DispatchQueue.main.async {
            var mainMessage = "Conversion completed successfully!"
            var compressionInfo = ""

            if let originalURL = self.inputURL, let outputURL = self.currentOutputURL {
                mainMessage = "Converted: \(outputURL.lastPathComponent)" // More specific success

                if let originalSize = FileUtilities.getFileSize(url: originalURL),
                   let newSize = FileUtilities.getFileSize(url: outputURL) {

                    let formattedOriginalSize = FileUtilities.formatBytes(originalSize)
                    let formattedNewSize = FileUtilities.formatBytes(newSize)
                    compressionInfo += "\nOriginal: \(formattedOriginalSize), New: \(formattedNewSize)."

                    if originalSize > 0 { // Avoid division by zero
                        if newSize < originalSize {
                            let percentageSmaller = (Double(originalSize - newSize) / Double(originalSize)) * 100.0
                            compressionInfo += String(format: " Reduced by %.1f%%.", percentageSmaller)
                        } else if newSize > originalSize {
                            let percentageLarger = (Double(newSize - originalSize) / Double(originalSize)) * 100.0
                            compressionInfo += String(format: " Increased by %.1f%%.", percentageLarger)
                        } else {
                            compressionInfo += " File size is the same."
                        }
                    }
                } else {
                    compressionInfo += "\nCould not determine file sizes for compression info."
                }
            }

            self.successMessage = mainMessage + compressionInfo
            self.conversionDidEnd()
            // Optionally clear input after success:
            // self.inputURL = nil // This would also clear defaultOutputURL
            // self.currentOutputURL = nil // Clear after use
        }
    }
}
