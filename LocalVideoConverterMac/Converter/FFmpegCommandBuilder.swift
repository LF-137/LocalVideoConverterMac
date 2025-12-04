import Foundation

class FFmpegCommandBuilder {

    // MARK: - Video Command
    func buildVideoCommand(inputURL: URL, outputURL: URL, outputFormat: OutputFormat, videoCodec: VideoCodec, videoQuality: VideoQuality, audioCodec: AudioCodec) -> [String] {

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
            arguments.append(contentsOf: ["-pix_fmt", "yuv420p"])

        case .hevc:
            arguments.append(contentsOf: ["-c:v", "libx265", "-tag:v", "hvc1"])
            switch videoQuality {
            case .high:   arguments.append(contentsOf: ["-crf", "20", "-preset", "slow"])
            case .medium: arguments.append(contentsOf: ["-crf", "26", "-preset", "medium"])
            case .low:    arguments.append(contentsOf: ["-crf", "30", "-preset", "fast"])
            }
        }

        // Audio Settings for Video
        switch audioCodec {
        case .aac: arguments.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])
        case .mp3: arguments.append(contentsOf: ["-c:a", "libmp3lame", "-b:a", "192k"])
        case .none: arguments.append("-an")
        }

        if outputFormat == .mp4 { arguments.append(contentsOf: ["-movflags", "+faststart"]) }
        
        arguments.append(outputURL.path)
        return arguments
    }
    
    // MARK: - Audio Extraction Commands
    
    private func getCodecArgs(for format: AudioExportFormat) -> [String] {
        switch format {
        case .mp3: return ["-c:a", "libmp3lame", "-q:a", "2"] // VBR High Quality
        case .aac: return ["-c:a", "aac", "-b:a", "256k"]
        case .wav: return ["-c:a", "pcm_s16le"]
        case .flac: return ["-c:a", "flac"]
        }
    }
    
    func buildSingleTrackExtraction(inputURL: URL, outputURL: URL, trackIndex: Int, format: AudioExportFormat) -> [String] {
        var args = ["-y", "-i", inputURL.path, "-progress", "pipe:1"]
        
        // Map specific audio stream: -map 0:a:INDEX
        args.append(contentsOf: ["-map", "0:a:\(trackIndex)"])
        
        // Apply Codec
        args.append(contentsOf: getCodecArgs(for: format))
        
        args.append(outputURL.path)
        return args
    }
    
    func buildMergedAudioCommand(inputURL: URL, outputURL: URL, trackIndices: [Int], format: AudioExportFormat) -> [String] {
        var args = ["-y", "-i", inputURL.path, "-progress", "pipe:1"]
        
        // Complex Filter for Mixing
        // Example: [0:a:0][0:a:1]amix=inputs=2[out]
        var inputTags = ""
        for index in trackIndices {
            inputTags += "[0:a:\(index)]"
        }
        let filter = "\(inputTags)amix=inputs=\(trackIndices.count):dropout_transition=2[out]"
        
        args.append(contentsOf: ["-filter_complex", filter])
        args.append(contentsOf: ["-map", "[out]"])
        
        // Apply Codec
        args.append(contentsOf: getCodecArgs(for: format))
        
        args.append(outputURL.path)
        return args
    }
}
