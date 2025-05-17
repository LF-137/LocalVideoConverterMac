import Foundation

// MARK: - Conversion Settings Enums

enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4, mov // Add more as needed, e.g., mkv, webm

    var id: String { self.rawValue }
    var displayName: String { self.rawValue.uppercased() }
}

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264
    case hevc
    // Add more as needed, e.g., vp9, av1 (ensure ffmpeg build supports them)

    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .h264: return "H.264 (libx264)"
        case .hevc: return "HEVC (H.265, libx265)"
        }
    }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case high, medium, low

    var id: String { self.rawValue }
    var displayName: String { self.rawValue.capitalized }
}

enum AudioCodec: String, CaseIterable, Identifiable {
    case aac, mp3, none // Add more as needed, e.g., opus, flac

    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .aac: return "AAC"
        case .mp3: return "MP3 (LAME)"
        case .none: return "None (No Audio)"
        }
    }
}
