import Foundation

/// Constructs FFmpeg command-line argument arrays based on specified conversion settings.
/// Uses the `-progress pipe:1` argument for reliable progress reporting via standard output.
class FFmpegCommandBuilder {

    /// Builds the argument array for an FFmpeg conversion command.
    ///
    /// - Parameters:
    ///   - inputURL: URL of the input video file.
    ///   - outputURL: URL for the output video file.
    ///   - outputFormat: Desired output container format (enum).
    ///   - videoCodec: Target video codec (enum).
    ///   - videoQuality: Quality preset (enum).
    ///   - audioCodec: Target audio codec (enum).
    /// - Returns: An array of strings representing the FFmpeg command arguments.
    func buildCommand(inputURL: URL, outputURL: URL, outputFormat: OutputFormat, videoCodec: VideoCodec, videoQuality: VideoQuality, audioCodec: AudioCodec) -> [String] {

        // --- Core Arguments ---
        var arguments = ["-y", "-i", inputURL.path, "-progress", "pipe:1"]

        // --- Video Settings ---
        switch videoCodec {
        case .h264:
            arguments.append(contentsOf: ["-c:v", "libx264"])
            switch videoQuality {
            case .high: arguments.append(contentsOf: ["-crf", "19", "-preset", "medium"])
            case .medium: arguments.append(contentsOf: ["-crf", "22", "-preset", "medium"])
            case .low: arguments.append(contentsOf: ["-crf", "25", "-preset", "fast"])
            }
            // Pixel format for H.264 compatibility, especially for older players/QuickTime
            arguments.append(contentsOf: ["-pix_fmt", "yuv420p"])


        case .hevc:
            arguments.append(contentsOf: ["-c:v", "libx265"])
            arguments.append(contentsOf: ["-tag:v", "hvc1"]) // Apple compatibility
            switch videoQuality {
            case .high: arguments.append(contentsOf: ["-crf", "21", "-preset", "medium"])
            case .medium: arguments.append(contentsOf: ["-crf", "24", "-preset", "medium"])
            case .low: arguments.append(contentsOf: ["-crf", "28", "-preset", "fast"])
            }
        // Add other video codec cases from your enum here if you expand it
        // default:
        //     // This case should ideally not be hit if UI is driven by enums
        //     print("Warning: Unknown video codec '\(videoCodec.rawValue)'. Defaulting to H.264 (libx264).")
        //     arguments.append(contentsOf: ["-c:v", "libx264", "-crf", "23", "-preset", "medium", "-pix_fmt", "yuv420p"])
        }


        // --- Audio Settings ---
        switch audioCodec {
        case .aac:
            arguments.append(contentsOf: ["-c:a", "aac"])
            arguments.append(contentsOf: ["-b:a", "192k"]) // Example bitrate
        case .mp3:
            arguments.append(contentsOf: ["-c:a", "libmp3lame"])
            arguments.append(contentsOf: ["-b:a", "192k"]) // Example bitrate
        case .none:
            arguments.append("-an") // No audio
        // Add other audio codec cases from your enum here
        // default:
        //     // This case should ideally not be hit
        //     print("Warning: Unknown audio codec '\(audioCodec.rawValue)'. Defaulting to AAC.")
        //     arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])
        }

        // --- Output Format Specifics (if any) ---
        // For example, MP4 benefits from `movflags +faststart` for web streaming
        if outputFormat == .mp4 {
            arguments.append(contentsOf: ["-movflags", "+faststart"])
        }
        // Note: The output file extension is handled by `outputURL` itself,
        // which `VideoConverter` prepares based on `outputFormat.rawValue`.
        // FFmpeg typically infers container format from output file extension,
        // but explicitly setting `-f format` can be done if needed for complex cases.

        // --- Output File ---
        arguments.append(outputURL.path)

        return arguments
    }
}
