import Foundation

/// Protocol definition for delegates that want to receive updates from `FFmpegProcessRunner`.
///
/// Any class that conforms to this protocol can act as a delegate for `FFmpegProcessRunner`
/// and be notified about the progress, errors, and completion of FFmpeg process execution.
protocol FFmpegProcessRunnerDelegate: AnyObject {
    /// Called periodically by `FFmpegProcessRunner` to report the current progress of the FFmpeg process.
    ///
    /// - Parameter progress: A `Double` value between 0.0 and 1.0 indicating the conversion progress.
    ///                      0.0 represents the start, and 1.0 represents completion.
    func processRunnerDidUpdateProgress(_ progress: Double)

    /// Called by `FFmpegProcessRunner` when the FFmpeg process fails to complete successfully due to an error.
    ///
    /// - Parameter error: A `String` containing a description of the error that occurred during FFmpeg processing.
    func processRunnerDidFailWithError(_ error: String)

    /// Called by `FFmpegProcessRunner` when the FFmpeg process finishes successfully without any errors.
    ///
    /// No parameters are passed, as this method simply indicates successful completion.
    func processRunnerDidFinish()
}
