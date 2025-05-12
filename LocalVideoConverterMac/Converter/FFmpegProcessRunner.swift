import Foundation
import AVFoundation // For video duration
import OSLog // Use modern Logging

/// Handles the execution and monitoring of the `ffmpeg` command-line tool.
/// Uses `Process` to run FFmpeg, captures stdout for progress data (via `-progress pipe:1`),
/// and stderr for final error checking. Notifies a delegate about progress and completion.
class FFmpegProcessRunner {

    // MARK: - Properties

    /// The currently active `ffmpeg` process. Managed internally.
    private var process: Process?
    /// Pipe to capture standard error output (used for final error messages).
    private var errorPipe: Pipe?
    /// Pipe to capture standard output (used for `-progress` data).
    private var outputPipe: Pipe?
    /// Delegate notified of progress, success, or failure. Must be weak to prevent retain cycles.
    weak var delegate: FFmpegProcessRunnerDelegate?
    /// Expected duration of the input video in seconds, used for progress calculation.
    private var videoDuration: Double = 0.0

    /// Buffer accumulating stderr data until the process terminates.
    private var errorDataBuffer = Data()
    /// Buffer accumulating stdout data (progress lines) until processed line-by-line.
    private var progressDataBuffer = Data()

    /// Dedicated logger for this class. Subsystem should match your app's bundle ID.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.videoconverter", category: "FFmpegProcessRunner")

    /// Pre-compiled regex for parsing "out_time_us=..." from FFmpeg's `-progress` output.
    private let progressTimeRegex = try? NSRegularExpression(pattern: #"out_time_us=(\d+)"#)

    // MARK: - Public Methods

    /// Runs the FFmpeg command asynchronously with specified arguments.
    /// Reads progress data from standard output (`pipe:1`).
    ///
    /// - Parameters:
    ///   - ffmpegPath: The absolute path to the `ffmpeg` executable.
    ///   - arguments: An array of command-line arguments for `ffmpeg` (should include `-progress pipe:1`).
    ///   - inputURL: The URL of the input video (used to calculate duration).
    func run(ffmpegPath: String, arguments: [String], inputURL: URL) {
        // Create a new Task to run the process off the main thread.
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return } // Ensure self is available

            self.resetState() // Clear previous state
            self.videoDuration = await self.getVideoDuration(inputURL) // Load duration asynchronously

            // Validate duration before proceeding
            guard self.videoDuration > 0 else {
                self.logger.error("Could not determine video duration for progress calculation. Aborting.")
                self.delegate?.processRunnerDidFailWithError("Could not read video duration from input file.")
                return // Exit if duration is invalid
            }

            self.logger.info("Starting FFmpeg process with -progress pipe:1.")
            self.logger.debug("""
                FFmpeg Path: \(ffmpegPath)
                FFmpeg Arguments: \(arguments.joined(separator: " "), privacy: .sensitive)
                Video Duration: \(self.videoDuration) seconds
                """)

            // --- Process Setup ---
            let task = Process()
            task.launchPath = ffmpegPath
            task.arguments = arguments

            // Setup pipes for standard output and standard error
            let outPipe = Pipe(); task.standardOutput = outPipe; self.outputPipe = outPipe
            let errPipe = Pipe(); task.standardError = errPipe; self.errorPipe = errPipe

            // --- Stdout Readability Handler (for Progress) ---
            // Reads data from stdout (`pipe:1`) as FFmpeg sends progress updates.
            outPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                // self.logger.trace("Stdout Readability Handler Entered.") // Debug log (optional)
                let availableData = fileHandle.availableData
                if !availableData.isEmpty {
                    // Process the incoming chunk of progress data
                    self.processProgressData(availableData)
                } else {
                    // EOF on stdout pipe usually means process is finishing/finished
                    self.logger.trace("Stdout Readability handler found empty data (likely EOF).")
                }
            }

            // --- Termination Handler ---
            // Called when the FFmpeg process terminates (completes, fails, or is cancelled).
            task.terminationHandler = { finishedProcess in
                let termStatus = finishedProcess.terminationStatus
                let termReason = finishedProcess.terminationReason
                self.logger.info("Termination Handler Entered. Status: \(termStatus), Reason: \(termReason.rawValue)")

                // Perform cleanup and delegate notification within a separate Task
                // to avoid blocking the termination handler thread.
                Task { [weak self] in
                    guard let self = self else { return }
                    self.logger.info("Termination Handler Task Started.")

                    // Ensure stdout handler is removed before reading final pipe data to prevent race conditions.
                    self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                    self.logger.debug("Termination Handler: Stdout readability handler removed.")

                    // Read any remaining data buffered in the pipes.
                    var remainingOutputData = Data()
                    var remainingErrorData = Data()
                    do {
                         // Reading stdout first ensures we get final progress data if handler was slightly delayed.
                         remainingOutputData = (try self.outputPipe?.fileHandleForReading.readToEnd()) ?? Data()
                         remainingErrorData = (try self.errorPipe?.fileHandleForReading.readToEnd()) ?? Data()
                         self.logger.debug("Termination Handler: Read remaining pipe data (stdout: \(remainingOutputData.count) bytes, stderr: \(remainingErrorData.count) bytes).")
                    } catch {
                         self.logger.error("Termination Handler: Error reading pipe to end: \(error.localizedDescription)")
                    }

                    // Process any final chunk of progress data from stdout.
                    self.progressDataBuffer.append(remainingOutputData)
                    if !self.progressDataBuffer.isEmpty {
                         self.logger.debug("Termination Handler: Processing final progress data buffer.")
                         self.processProgressData(Data()) // Send empty data to flush buffer
                    }

                    // Combine buffered stderr data with final read chunk.
                    self.errorDataBuffer.append(remainingErrorData)
                    let finalErrorString = String(data: self.errorDataBuffer, encoding: .utf8) ?? ""

                    // Log final stderr content if not empty (useful for debugging failures).
                     if !finalErrorString.isEmpty {
                         self.logger.debug("FFmpeg Standard Error (Final):\n---\n\(finalErrorString)\n---")
                     } else {
                         self.logger.debug("Termination Handler: No final standard error data.")
                     }

                    // --- Determine Result and Notify Delegate ---
                    if termStatus == 0 { // Success exit code
                        // Double-check stderr for errors even on status 0
                        if let explicitError = self.extractError(from: finalErrorString) {
                             self.logger.error("FFmpeg exited status 0 but stderr contained errors: \(explicitError)")
                             self.delegate?.processRunnerDidFailWithError(explicitError)
                        } else {
                             self.logger.info("FFmpeg finished successfully.")
                             self.delegate?.processRunnerDidUpdateProgress(1.0) // Ensure 100%
                             self.delegate?.processRunnerDidFinish()
                        }
                    } else { // Failure exit code
                        var errorMsg = self.extractError(from: finalErrorString) ?? "FFmpeg failed with exit code: \(termStatus)."
                         if finalErrorString.isEmpty && errorMsg.contains("exit code:") {
                              errorMsg += " No specific error message found on stderr."
                         }

                         // Provide a clearer message if cancellation was the cause.
                         if termReason == .uncaughtSignal && (termStatus == 15 /* SIGTERM */ || termStatus == 9 /* SIGKILL */) {
                             errorMsg = "Operation cancelled."
                             self.logger.info("FFmpeg process cancelled (Signal: \(termStatus)).")
                         } else {
                            self.logger.error("FFmpeg failed. Error: \(errorMsg)")
                         }
                         self.delegate?.processRunnerDidFailWithError(errorMsg)
                    }

                    self.resetState() // Perform final cleanup
                    self.logger.info("Termination Handler Task Completed.")
                } // End Task within terminationHandler
            } // End terminationHandler

            // --- Launch ---
            do {
                 self.logger.info("Launching FFmpeg process...")
                 try task.run()
                 self.process = task // Store the running process reference
                 self.logger.info("FFmpeg process launched successfully (PID: \(task.processIdentifier)).")
            } catch {
                 self.logger.critical("Failed to launch FFmpeg process: \(error.localizedDescription)")
                 self.delegate?.processRunnerDidFailWithError("Failed to start FFmpeg: \(error.localizedDescription)")
                 self.resetState() // Clean up if launch fails
            }
        } // End main Task
    } // End run()

    /// Cancels the currently running FFmpeg process, if any.
    /// Sends a termination signal (SIGTERM). Cleanup is handled by the terminationHandler.
    func cancel() {
        Task { [weak self] in // Run cancellation check on a background Task
             guard let self = self else { return }
            guard let runningProcess = self.process, runningProcess.isRunning else {
                self.logger.info("Cancel requested, but no process is running.")
                return
            }
            self.logger.info("Terminating FFmpeg process (PID: \(runningProcess.processIdentifier))...")
            // Ensure handler is removed *before* sending terminate signal
            self.outputPipe?.fileHandleForReading.readabilityHandler = nil
            runningProcess.terminate() // Sends SIGTERM
            // self.process will be nil'd by resetState() in the termination handler
        }
    }

    // MARK: - Private Helper Methods

    /// Resets internal state variables and closes pipe file handles.
    /// Called before starting a new process and after a process terminates.
    private func resetState() {
        self.logger.debug("Resetting FFmpegProcessRunner state.")
        // Close pipe handles explicitly to release resources
        try? self.errorPipe?.fileHandleForReading.close()
        try? self.errorPipe?.fileHandleForWriting.close()
        try? self.outputPipe?.fileHandleForReading.close()
        try? self.outputPipe?.fileHandleForWriting.close()

        // Nil out references
        self.process = nil
        self.errorPipe = nil
        self.outputPipe = nil
        self.errorDataBuffer = Data()
        self.progressDataBuffer = Data()
        self.videoDuration = 0.0
    }

    /// Processes chunks of data read from the standard output pipe (containing `-progress` data).
    /// Appends data to `progressDataBuffer` and processes completed lines.
    /// - Parameter data: A chunk of data read from the stdout pipe.
    private func processProgressData(_ data: Data) {
        self.progressDataBuffer.append(data)

        // Process the buffer line by line, as progress updates are newline-terminated.
        while let range = self.progressDataBuffer.range(of: Data("\n".utf8)) {
            let lineData = self.progressDataBuffer.subdata(in: 0..<range.lowerBound)
            // Remove the processed line (including the newline) from the buffer.
            self.progressDataBuffer.removeSubrange(0..<range.upperBound)

            if let line = String(data: lineData, encoding: .utf8) {
                 // self.logger.trace("FFmpeg stdout progress line: \(line)") // Optional: Log every line
                // Attempt to parse the key=value progress data from the line.
                self.parseProgressTime(from: line)
            }
        }
        // Any remaining data in progressDataBuffer is a partial line, wait for the next chunk.
    }

    /// Parses a single line of FFmpeg's `-progress` output (e.g., "out_time_us=1234567").
    /// Extracts the timestamp, calculates progress, and notifies the delegate.
    /// - Parameter line: A line of text from the progress output stream.
    private func parseProgressTime(from line: String) {
        // Use pre-compiled regex to find the microseconds timestamp.
        guard let regex = self.progressTimeRegex,
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 2, // Ensure the capture group (index 1) exists.
              let timeRange = Range(match.range(at: 1), in: line),
              let timeMicroseconds = Double(String(line[timeRange])) // Extract the numeric value.
        else {
            // Line doesn't contain the expected 'out_time_us=' key or valid number.
            return
        }

        // Convert microseconds to seconds for comparison with duration.
        let currentTimeSeconds = timeMicroseconds / 1_000_000.0

        // Calculate progress percentage if duration is valid.
        if self.videoDuration > 0 {
            // Clamp progress between 0.0 and 1.0 to handle potential timing inaccuracies.
            let calculatedProgress = min(1.0, max(0.0, currentTimeSeconds / self.videoDuration))
            // self.logger.trace("Calculated Progress: \(calculatedProgress * 100.0)%") // Optional: Log calculated %
            // Notify the delegate with the updated progress.
            self.delegate?.processRunnerDidUpdateProgress(calculatedProgress)
        }
    }

    /// Attempts to find a specific error message within the final stderr output.
    /// Useful for providing more context than just an exit code.
    /// - Parameter stderr: The complete standard error output string.
    /// - Returns: A relevant error line, or `nil` if no common error pattern is found.
    private func extractError(from stderr: String) -> String? {
         let lines = stderr.split(separator: "\n", omittingEmptySubsequences: true)
         // Check last few lines first, as errors often appear near the end.
         for line in lines.reversed().prefix(10) { // Check last 10 non-empty lines
             let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
             // Look for common error keywords/phrases
             let lowerTrimmed = trimmed.lowercased()
             if lowerTrimmed.hasPrefix("error") ||
                lowerTrimmed.contains("unknown encoder") ||
                lowerTrimmed.contains("invalid argument") ||
                lowerTrimmed.contains("failed") ||
                lowerTrimmed.contains("could not write header") ||
                lowerTrimmed.contains("no such file or directory")
             {
                 return trimmed // Return the first significant error line found
             }
         }
         return nil // No common error pattern detected
     }

    /// Asynchronously loads the duration of the video asset.
    /// - Parameter url: The URL of the video file.
    /// - Returns: The duration in seconds, or 0.0 if loading fails or duration is invalid.
    private func getVideoDuration(_ url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            // Use the modern async load method for duration.
            let loadedDuration = try await asset.load(.duration)
            // Validate the loaded time value.
            if loadedDuration.timescale > 0 {
                let durationInSeconds = CMTimeGetSeconds(loadedDuration)
                self.logger.debug("Successfully loaded duration for \(url.lastPathComponent, privacy: .public): \(durationInSeconds) seconds")
                return durationInSeconds
            } else {
                // Timescale <= 0 indicates an invalid or indefinite time.
                self.logger.warning("Loaded duration for \(url.lastPathComponent, privacy: .public) has invalid timescale: \(loadedDuration.timescale)")
                return 0.0
            }
        } catch {
            // Log any errors encountered during loading (e.g., file not found, unreadable).
            self.logger.error("Failed to load duration for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription)")
            return 0.0 // Return 0.0 to indicate failure
        }
    }
}
