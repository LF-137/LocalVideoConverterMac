import Foundation

// MARK: - Conversion Settings Enums
// OutputFormat, VideoCodec, VideoQuality, AudioCodec enums remain the same as before

enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4, mov
    var id: String { self.rawValue }
    var displayName: String { self.rawValue.uppercased() }
}
enum VideoCodec: String, CaseIterable, Identifiable {
    case h264, hevc
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
    case aac, mp3, none
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .aac: return "AAC"
        case .mp3: return "MP3 (LAME)"
        case .none: return "None (No Audio)"
        }
    }
}


// MARK: - File Queue Item and Status

struct FileQueueItem: Identifiable, Equatable {
    let id = UUID() // Primary identifier for SwiftUI's ForEach
    let inputURL: URL
    var outputURL: URL?
    var status: ConversionStatus = .pending
    var progress: Double = 0.0
    var errorMessage: String?
    var successMessage: String?
    var securityScopedInputURL: URL?

    // Equatable: Compare all relevant fields that might change and require a UI update.
    // SwiftUI's List might use this to determine if a row needs redrawing
    // when the array itself is signaled as changed.
    static func == (lhs: FileQueueItem, rhs: FileQueueItem) -> Bool {
        return lhs.id == rhs.id && // Must have same ID to be considered "the same item"
               lhs.status == rhs.status &&
               lhs.progress == rhs.progress && // Compare progress for progress bar updates
               lhs.errorMessage == rhs.errorMessage &&
               lhs.successMessage == rhs.successMessage &&
               lhs.outputURL == rhs.outputURL // Output URL might be set later
        // We don't compare inputURL or securityScopedInputURL because they are set at creation
        // and shouldn't change for the *same* item ID.
    }
}

enum ConversionStatus: String, CaseIterable {
    case pending = "Pending"
    case preparing = "Preparing"
    case converting = "Converting"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case skipped = "Skipped (Output Exists)"

    var displayName: String {
        self.rawValue
    }
}
