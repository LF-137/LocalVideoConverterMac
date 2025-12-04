import Foundation

// MARK: - Enums
// We ensure RawRepresentable (String) is used so @AppStorage works automatically

enum ConversionMode: String, CaseIterable, Identifiable {
    case videoConversion = "Convert Video"
    case audioExtraction = "Extract Audio"
    var id: String { self.rawValue }
}

enum AudioExportFormat: String, CaseIterable, Identifiable {
    case mp3, aac, wav, flac
    var id: String { self.rawValue }
    var displayName: String { self.rawValue.uppercased() }
    var extensionName: String { self.rawValue }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4, mov, mkv
    var id: String { self.rawValue }
    var displayName: String { self.rawValue.uppercased() }
}

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264, hevc
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .h264: return "H.264 (Standard)"
        case .hevc: return "HEVC (H.265)"
        }
    }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case high, medium, low
    var id: String { self.rawValue }
    var displayName: String { self.rawValue.capitalized }
}

enum AudioCodec: String, CaseIterable, Identifiable {
    case aac, mp3, none
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .aac: return "AAC"
        case .mp3: return "MP3"
        case .none: return "None (No Audio)"
        }
    }
}

enum ConversionStatus: String, CaseIterable {
    case pending = "Pending"
    case analyzing = "Analyzing..."
    case preparing = "Preparing"
    case converting = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var displayName: String { self.rawValue }
}

// MARK: - Data Models

struct AudioTrackInfo: Identifiable, Equatable {
    let id = UUID()
    let index: Int // The index in FFmpeg (0:a:0, 0:a:1)
    var language: String
    var title: String
    
    // UI State for Extraction
    var isSelected: Bool = false
    var customName: String = "" // User defined output filename
}

struct FileQueueItem: Identifiable, Equatable {
    let id = UUID()
    let inputURL: URL
    var outputURL: URL? // Used for video conversion
    var securityScopedInputURL: URL?
    
    var status: ConversionStatus = .pending
    var progress: Double = 0.0
    var errorMessage: String?
    var successMessage: String?
    
    // Audio Extraction Specifics
    var audioTracks: [AudioTrackInfo] = []
    var mergeSelectedTracks: Bool = false
    var mergedTrackName: String = ""
    
    // Helper to see if any work is selected
    var hasWorkToDo: Bool {
        return audioTracks.contains(where: { $0.isSelected }) || mergeSelectedTracks
    }

    static func == (lhs: FileQueueItem, rhs: FileQueueItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.status == rhs.status &&
               lhs.progress == rhs.progress &&
               lhs.errorMessage == rhs.errorMessage &&
               lhs.successMessage == rhs.successMessage &&
               lhs.audioTracks == rhs.audioTracks &&
               lhs.mergeSelectedTracks == rhs.mergeSelectedTracks
    }
}
