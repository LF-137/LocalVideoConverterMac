import Foundation

class FFmpegCommandBuilder {
    /// Builds an array of strings representing the FFmpeg command-line arguments for video conversion.
    ///
    /// - Parameters:
    ///   - inputURL: URL of the input video file.
    ///   - outputURL: URL for the output video file.
    ///   - outputFormat: Output file format (e.g., "mp4", "mov").
    ///   - videoCodec: Video codec for encoding (e.g., "h264", "hevc").
    ///   - videoQuality: Video quality setting ("high", "medium", "low"), used to determine CRF value.
    ///   - audioCodec: Audio codec for encoding (e.g., "aac", "mp3", "none").
    /// - Returns: An array of strings representing the FFmpeg command.
    func buildCommand(inputURL: URL, outputURL: URL, outputFormat: String, videoCodec: String, videoQuality: String, audioCodec: String) -> [String] {
        var arguments = ["-i", inputURL.path] // Start with input file path

        arguments.append(contentsOf: ["-pix_fmt", "nv12"]) // Pixel format for hardware encoders

        // MARK: - Video Codec and Quality Settings

        switch videoCodec {
        case "h264":
            // H.264 encoding using VideoToolbox hardware encoder (libx264 software encoder is used now)
            arguments.append(contentsOf: ["-c:v", "libx264"]) // Use libx264 software encoder
            arguments.append(contentsOf: ["-profile:v", "high"]) // Set H.264 profile

            switch videoQuality { // Quality based CRF setting for H.264
            case "high":
                arguments.append(contentsOf: ["-crf", "18"]) // High quality: lower CRF for better quality, larger file
            case "medium":
                arguments.append(contentsOf: ["-crf", "21"]) // Medium quality: balanced quality and file size
            case "low":
                arguments.append(contentsOf: ["-preset", "faster"]) // Faster preset for low quality encoding
                arguments.append(contentsOf: ["-crf", "24"])      // Low quality: higher CRF for smaller file, lower quality
            default:
                arguments.append(contentsOf: ["-crf", "21"]) // Default to medium quality if setting is unknown
            }

        case "hevc":
            // HEVC (H.265) encoding using libx265 software encoder (VideoToolbox hardware encoder removed for now)
            arguments.append(contentsOf: ["-c:v", "libx265"]) // Use libx265 software encoder

            switch videoQuality { // Quality based CRF setting for HEVC
            case "high":
                arguments.append(contentsOf: ["-crf", "20"]) // High quality: lower CRF for better quality, larger file
            case "medium":
                arguments.append(contentsOf: ["-crf", "23"]) // Medium quality: balanced quality and file size
            case "low":
                arguments.append(contentsOf: ["-preset", "faster"]) // Faster preset for low quality encoding
                arguments.append(contentsOf: ["-crf", "28"])      // Low quality: higher CRF for smaller file, lower quality
            default:
                arguments.append(contentsOf: ["-crf", "23"]) // Default to medium quality if setting is unknown
            }

        default: // Default video codec: H.264 (libx264) with medium quality
            arguments.append(contentsOf: ["-c:v", "libx264", "-crf", "23"]) // Default to libx264 with medium CRF
        }

        // MARK: - Audio Codec Settings

        switch audioCodec {
        case "aac":
            arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"]) // AAC audio codec, 192kbps bitrate
        case "mp3":
            arguments.append(contentsOf: ["-c:a", "libmp3lame", "-b:a", "192k"]) // MP3 audio codec, 192kbps bitrate
        case "none":
            arguments.append(contentsOf: ["-an"]) // No audio
        default: // Default audio codec: AAC
            arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"]) // Default to AAC audio codec
        }

        arguments.append(contentsOf: ["-f", outputFormat, outputURL.path]) // Output format and output file path
        return arguments
    }
}
