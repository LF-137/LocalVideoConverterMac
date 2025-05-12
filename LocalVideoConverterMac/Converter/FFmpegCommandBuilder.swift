import Foundation

/// Constructs FFmpeg command-line argument arrays based on specified conversion settings.
/// Uses the `-progress pipe:1` argument for reliable progress reporting via standard output.
class FFmpegCommandBuilder {

    /// Builds the argument array for an FFmpeg conversion command.
    ///
    /// - Parameters:
    ///   - inputURL: URL of the input video file.
    ///   - outputURL: URL for the output video file.
    ///   - outputFormat: Desired output container format (e.g., "mp4").
    ///   - videoCodec: Target video codec (e.g., "h264", "hevc").
    ///   - videoQuality: Quality preset ("high", "medium", "low") mapping to CRF/preset values.
    ///   - audioCodec: Target audio codec (e.g., "aac", "mp3", "none").
    /// - Returns: An array of strings representing the FFmpeg command arguments.
    func buildCommand(inputURL: URL, outputURL: URL, outputFormat: String, videoCodec: String, videoQuality: String, audioCodec: String) -> [String] {

        // --- Core Arguments ---
        // -y: Overwrite output files without asking.
        // -i [input path]: Specify the input file.
        // -progress pipe:1: Send detailed progress updates to standard output (file descriptor 1).
        var arguments = ["-y", "-i", inputURL.path, "-progress", "pipe:1"]

        // --- Video Settings ---
        switch videoCodec {
        case "h264":
            arguments.append(contentsOf: ["-c:v", "libx264"]) // Software H.264 encoder
            // Adjust CRF (quality) and preset (speed/compression balance) based on user selection.
            // Lower CRF = better quality, larger file. Slower preset = better compression.
            switch videoQuality {
            case "high": arguments.append(contentsOf: ["-crf", "19", "-preset", "medium"]) // High quality, good balance
            case "medium": arguments.append(contentsOf: ["-crf", "22", "-preset", "medium"]) // Default balance
            case "low": arguments.append(contentsOf: ["-crf", "25", "-preset", "fast"])   // Lower quality, smaller file, faster
            default: arguments.append(contentsOf: ["-crf", "22", "-preset", "medium"])
            }

        case "hevc":
            arguments.append(contentsOf: ["-c:v", "libx265"]) // Software HEVC encoder
            // -tag:v hvc1 helps compatibility with Apple devices/QuickTime.
            arguments.append(contentsOf: ["-tag:v", "hvc1"])
            // CRF values for HEVC are interpreted differently. Generally higher values than H.264 for similar quality.
            switch videoQuality {
            case "high": arguments.append(contentsOf: ["-crf", "21", "-preset", "medium"])
            case "medium": arguments.append(contentsOf: ["-crf", "24", "-preset", "medium"])
            case "low": arguments.append(contentsOf: ["-crf", "28", "-preset", "fast"])
            default: arguments.append(contentsOf: ["-crf", "24", "-preset", "medium"])
            }

        // Add other video codec cases here (e.g., AV1, VP9, hardware accelerated)

        default:
            // Fallback if an unknown video codec is selected. Defaulting to H.264 medium.
             print("Warning: Unknown video codec '\(videoCodec)'. Defaulting to H.264 (libx264).")
             arguments.append(contentsOf: ["-c:v", "libx264", "-crf", "23", "-preset", "medium"])
        }


        // --- Audio Settings ---
        switch audioCodec {
        case "aac":
            // Use FFmpeg's built-in AAC encoder (good quality, widely compatible).
            arguments.append(contentsOf: ["-c:a", "aac"])
            // Set audio bitrate (e.g., 192kbps for good quality stereo).
            arguments.append(contentsOf: ["-b:a", "192k"])
        case "mp3":
             // Use LAME MP3 encoder (requires FFmpeg compiled with --enable-libmp3lame).
            arguments.append(contentsOf: ["-c:a", "libmp3lame"])
            arguments.append(contentsOf: ["-b:a", "192k"])
        case "none":
            // Disable audio stream processing and output.
            arguments.append("-an")

        // Add other audio codec cases here (e.g., Opus, FLAC, copy)

        default:
            // Fallback for unknown audio codec. Defaulting to AAC.
             print("Warning: Unknown audio codec '\(audioCodec)'. Defaulting to AAC.")
             arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])
        }

        // --- Output File ---
        // Finally, add the path for the output file.
        arguments.append(outputURL.path)

        return arguments
    }
}
