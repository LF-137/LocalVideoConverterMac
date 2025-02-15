import Foundation
import AVFoundation
import AppKit

class FFmpegProcessRunner {
    // MARK: - Properties

    /// `Process` instance to manage the running FFmpeg task.
    private var process: Process?

    /// `Timer` to periodically check FFmpeg's progress output.
    private var progressTimer: Timer?

    /// Delegate to communicate progress updates, errors, and completion to the `VideoConverter`.
    weak var delegate: FFmpegProcessRunnerDelegate?


    // MARK: - FFmpeg Execution

    /// Executes the FFmpeg command with the given path and arguments.
    ///
    /// - Parameters:
    ///   - ffmpegPath: Path to the FFmpeg executable.
    ///   - arguments: Array of strings representing FFmpeg command-line arguments.
    ///   - inputURL: URL of the input video file (used to determine video duration).
    func run(ffmpegPath: String, arguments: [String], inputURL: URL) {
        print("FFmpegProcessRunner: run() called")
        print("FFmpeg Path: \(ffmpegPath)")
        print("FFmpeg Arguments: \(arguments)")

        let task = Process() // Create a new Process instance
        self.process = task  // Store the process instance for potential cancellation
        task.launchPath = ffmpegPath // Set the executable path for the task
        task.arguments = arguments  // Set the arguments for the task

        let errorPipe = Pipe() // Pipe for capturing FFmpeg standard error output
        task.standardError = errorPipe

        let outputPipe = Pipe() // Pipe for capturing FFmpeg standard output (though primarily progress is on stderr)
        task.standardOutput = outputPipe

        let duration = self.getVideoDuration(inputURL) // Get video duration to calculate progress
        print("Video Duration: \(duration)")

        // MARK: - Progress Monitoring Timer

        // Timer to periodically read FFmpeg's stderr output to track progress
        self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in // Use weak self to avoid retain cycle
            guard let self = self else { return } // Safely unwrap self

            let errorData = errorPipe.fileHandleForReading.availableData // Read available data from error pipe
            if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8) { // If there's error output
                print("FFmpeg Error Output (during progress): \(errorString)")

                // Regular expression to extract "time=HH:MM:SS.ms" from FFmpeg stderr output
                if let timeRange = errorString.range(of: "time=(\\d+:\\d+:\\d+(?:\\.\\d+)?)", options: .regularExpression) {
                    let timeString = String(errorString[timeRange].dropFirst(5)) // Extract time string
                    let currentTimeInSeconds = self.timeStringToSeconds(timeString) // Convert time string to seconds
                    let calculatedProgress = duration > 0 ? min(1.0, currentTimeInSeconds / duration) : 0.0 // Calculate progress

                    self.delegate?.processRunnerDidUpdateProgress(calculatedProgress) // Notify delegate with progress update
                }
            }
        }
        RunLoop.current.add(self.progressTimer!, forMode: .common) // Add timer to RunLoop to start it

        // MARK: - Termination Handler

        // Completion handler for the FFmpeg task (called when FFmpeg finishes or is terminated)
        task.terminationHandler = { [weak self] process in // Use weak self to avoid retain cycle
            guard let self = self else { return } // Safely unwrap self
            print("FFmpegProcessRunner: terminationHandler called")

            DispatchQueue.main.async { // Ensure delegate calls are on the main thread
                self.progressTimer?.invalidate() // Stop progress timer
                self.progressTimer = nil
                self.process = nil // Clear process reference

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile() // Read any remaining error output
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile() // Read any standard output

                if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty { // Check for error output
                    print("FFmpeg Error Output (terminationHandler): \(errorString)")
                    self.delegate?.processRunnerDidFailWithError("FFmpeg error: \(errorString)") // Notify delegate about error
                } else if process.terminationStatus != 0 { // Check for non-zero termination status (error exit code)
                    print("FFmpeg Exit Code (terminationHandler): \(process.terminationStatus)")
                    self.delegate?.processRunnerDidFailWithError("FFmpeg failed with exit code: \(process.terminationStatus)") // Notify delegate about exit code error
                } else {
                    print("FFmpegProcessRunner: terminationHandler finished successfully")
                    self.delegate?.processRunnerDidFinish() // Notify delegate about successful finish
                }
                if let outputString = String(data: outputData, encoding: .utf8), !outputString.isEmpty { // Log any standard output (though usually empty)
                    print("FFmpeg Standard Output (terminationHandler): \(outputString)")
                }
            }
        }


        // MARK: - Launching the Task

        do {
            print("FFmpegProcessRunner: About to call task.run()")
            try task.run() // Launch the FFmpeg process
            print("FFmpegProcessRunner: task.run() completed")

            // Immediate check if task is running (for debugging purposes)
            if task.isRunning {
                print("FFmpegProcessRunner: task is still running (immediately after task.run())")
            } else {
                print("FFmpegProcessRunner: task is NOT running (immediately after task.run())")
                print("FFmpeg Exit Code (immediately after task.run()): \(task.terminationStatus)")
            }

        } catch {
            print("FFmpegProcessRunner: Failed to start FFmpeg: \(error)")
            DispatchQueue.main.async {
                self.delegate?.processRunnerDidFailWithError("Failed to start FFmpeg: \(error)") // Notify delegate about start error
            }
        }
    }


    // MARK: - Utility Functions

    /// Converts time string in "HH:MM:SS.ms" format to seconds.
    func timeStringToSeconds(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0 // Return 0 if parsing fails
        }
        return hours * 3600 + minutes * 60 + seconds // Calculate total seconds
    }


    /// Gets the duration of the video file from its URL.
    func getVideoDuration(_ url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        return Double(asset.duration.value) / Double(asset.duration.timescale) // Calculate duration in seconds
    }


    /// Cancels the currently running FFmpeg process and invalidates the progress timer.
    func cancel() {
        progressTimer?.invalidate() // Stop progress timer
        progressTimer = nil
        process?.terminate()      // Terminate FFmpeg process
        process = nil
    }
}
