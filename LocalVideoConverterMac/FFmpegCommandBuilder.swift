// MARK: - FFmpegCommandBuilder
// FFmpegCommandBuilder.swift
import Foundation

class FFmpegCommandBuilder {
    func buildCommand(inputURL: URL, outputURL: URL, outputFormat: String, videoCodec: String, videoQuality: String, audioCodec: String) -> [String] {
        var arguments = ["-i", inputURL.path]

        // Pixel Format
        arguments.append(contentsOf: ["-pix_fmt", "nv12"])

        // Video Codec and Quality
        switch videoCodec {
        case "h264":
            arguments.append(contentsOf: ["-c:v", "h264_videotoolbox"])
            arguments.append(contentsOf: ["-profile:v", "high"])
            switch videoQuality {
            case "high":
                arguments.append(contentsOf: ["-b:v", "8M"]) // Target Bitrate
            case "medium":
                arguments.append(contentsOf: ["-b:v", "5M"])
            case "low":
                arguments.append(contentsOf: ["-b:v", "2M"])
            default:
                arguments.append(contentsOf: ["-b:v", "5M"])
            }
        case "hevc":
            arguments.append(contentsOf: ["-c:v", "hevc_videotoolbox"])
            switch videoQuality {
            case "high":
                arguments.append(contentsOf: ["-b:v", "8M"])
            case "medium":
                arguments.append(contentsOf: ["-b:v", "5M"])
            case "low":
                arguments.append(contentsOf: ["-b:v", "2M"])
            default:
                arguments.append(contentsOf: ["-b:v", "5M"])
            }
            arguments.append(contentsOf: ["-tag:v", "hvc1"])

        default: // Default to h264
            arguments.append(contentsOf: ["-c:v", "h264_videotoolbox", "-b:v", "5M"])
        }

        // Audio Codec
        switch audioCodec {
        case "aac":
            arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])
        case "mp3":
            arguments.append(contentsOf: ["-c:a", "libmp3lame", "-b:a", "192k"])
        case "none":
            arguments.append(contentsOf: ["-an"])
        default:
            arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])
        }

        arguments.append(contentsOf: ["-f", outputFormat, outputURL.path])
        return arguments
    }
}
