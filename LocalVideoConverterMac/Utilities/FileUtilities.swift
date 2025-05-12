import Foundation
import AppKit
import UniformTypeIdentifiers // Import for UTType

/// Utility struct for file-related operations like opening, saving, and validating files.
struct FileUtilities {

    /// Presents a Save Panel to choose an output URL for the converted video.
    ///
    /// - Parameter defaultURL: The suggested URL (directory and filename) for the Save Panel.
    /// - Returns: The URL chosen by the user, or `nil` if cancelled.
    static func chooseOutputURL(defaultURL: URL, selectedFormat: String) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.directoryURL = defaultURL.deletingLastPathComponent()
        savePanel.nameFieldStringValue = defaultURL.deletingPathExtension().appendingPathExtension(selectedFormat).lastPathComponent

        // Set allowed content type based on selected format
        if let type = UTType(filenameExtension: selectedFormat) {
             savePanel.allowedContentTypes = [type]
        } else {
            // Fallback if type lookup fails (less common)
            savePanel.allowedContentTypes = [.movie, .video]
        }
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false // Don't allow arbitrary extensions

        if savePanel.runModal() == .OK {
            return savePanel.url
        }
        return nil
    }

    /// Checks if a given URL points to a potential video file based on common video UTTypes.
    /// This is generally more reliable than just checking extensions.
    ///
    /// - Parameter url: The URL of the file to check.
    /// - Returns: `true` if the file's type conforms to standard video types, `false` otherwise.
    static func isVideoFile(_ url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
              let type = resourceValues.contentType else {
            // Fallback to extension check if type cannot be determined
            let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
            return videoExtensions.contains(url.pathExtension.lowercased())
        }
        // Check against common video types
        return type.conforms(to: .video) || type.conforms(to: .movie)
    }


    /// Handles dropped items, extracting the first valid file URL.
    ///
    /// - Parameters:
    ///   - providers: An array of `NSItemProvider` from the drop operation.
    ///   - completion: Called with the first valid `URL` found, or `nil`.
    static func handleDrop(providers: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            completion(nil)
            return
        }

        // Load the item as a file URL asynchronously
        _ = provider.loadObject(ofClass: URL.self) { url, error in
             DispatchQueue.main.async { // Ensure completion is on main thread for UI updates
                 if let url = url {
                    // Check if it's a directory - we don't want directories
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                         completion(nil) // It's a directory
                    } else {
                         completion(url) // It's a file URL
                    }
                 } else {
                    print("Error loading dropped item: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                 }
             }
         }
    }


    /// Presents an Open Panel for selecting a single video file.
    /// Handles security-scoped resource access.
    ///
    /// - Parameter completion: Called with the selected `URL`, or `nil` if cancelled or invalid.
    static func selectFile(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video] // Allow standard video types
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            // Attempt to start security-scoped access immediately
            // The caller (VideoConverter) will be responsible for stopping it.
            if url.startAccessingSecurityScopedResource() {
                 // Perform the check *after* starting access, as type might not be readable otherwise
                 if FileUtilities.isVideoFile(url) {
                    completion(url) // It's a video, access started
                 } else {
                    url.stopAccessingSecurityScopedResource() // Not a video, stop access
                    completion(nil)
                 }
            } else {
                // Could not start access (permission issue, sandbox?)
                // Try checking if it's a video anyway, but access might fail later
                 if FileUtilities.isVideoFile(url) {
                     print("Warning: Could not start security-scoped access for \(url.lastPathComponent). Conversion might fail.")
                     completion(url) // Pass URL but warn
                 } else {
                     completion(nil) // Not a video, couldn't start access
                 }
            }
        } else {
            completion(nil) // User cancelled
        }
    }
}
