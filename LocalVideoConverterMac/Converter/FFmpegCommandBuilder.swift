import Foundation

class FFmpegCommandBuilder {

    func buildCommand(inputURL: URL, outputURL: URL, outputFormat: OutputFormat, videoCodec: VideoCodec, videoQuality: VideoQuality, audioCodec: AudioCodec) -> [String] {

        // Base command
        var arguments = ["-y", "-i", inputURL.path, "-progress", "pipe:1"]

        // Video Settings
        switch videoCodec {
        case .h264:
            arguments.append(contentsOf: ["-c:v", "libx264"])
            switch videoQuality {
            case .high:   arguments.append(contentsOf: ["-crf", "18", "-preset", "slow"])
            case .medium: arguments.append(contentsOf: ["-crf", "23", "-preset", "medium"])
            case .low:    arguments.append(contentsOf: ["-crf", "28", "-preset", "fast"])
            }
            arguments.append(contentsOf: ["-pix_fmt", "yuv420p"]) // Compatibility

        case .hevc:
            arguments.append(contentsOf: ["-c:v", "libx265", "-tag:v", "hvc1"])
            switch videoQuality {
            case .high:   arguments.append(contentsOf: ["-crf", "20", "-preset", "slow"])
            case .medium: arguments.append(contentsOf: ["-crf", "26", "-preset", "medium"])
            case .low:    arguments.append(contentsOf: ["-crf", "30", "-preset", "fast"])
            }
        }

        // Audio Settings
        switch audioCodec {
        case .aac:
            arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])
        case .mp3:
            arguments.append(contentsOf: ["-c:a", "libmp3lame", "-b:a", "192k"])
        case .none:
            arguments.append("-an")
        }

        // Container specifics
        if outputFormat == .mp4 {
            arguments.append(contentsOf: ["-movflags", "+faststart"])
        }

        arguments.append(outputURL.path)
        return arguments
    }
}
