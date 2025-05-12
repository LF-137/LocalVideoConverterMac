import Foundation

/// Protocol for delegates receiving updates from `FFmpegProcessRunner`.
/// Defines methods for progress reporting, error handling, and completion notification.
protocol FFmpegProcessRunnerDelegate: AnyObject { // Use AnyObject for weak reference capability

    /// Called periodically with the conversion progress.
    /// - Parameter progress: A value between 0.0 and 1.0.
    func processRunnerDidUpdateProgress(_ progress: Double)

    /// Called when the FFmpeg process fails.
    /// - Parameter error: A string describing the error.
    func processRunnerDidFailWithError(_ error: String)

    /// Called when the FFmpeg process completes successfully.
    func processRunnerDidFinish()
}
