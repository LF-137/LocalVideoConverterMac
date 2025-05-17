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

        if let type = UTType(filenameExtension: selectedFormat) {
             savePanel.allowedContentTypes = [type]
        } else {
            savePanel.allowedContentTypes = [.movie, .video]
        }
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false

        if savePanel.runModal() == .OK {
            return savePanel.url
        }
        return nil
    }

    /// Checks if a given URL points to a potential video file based on common video UTTypes.
    static func isVideoFile(_ url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
              let type = resourceValues.contentType else {
            let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"] // Common extensions
            return videoExtensions.contains(url.pathExtension.lowercased())
        }
        return type.conforms(to: .video) || type.conforms(to: .movie)
    }


    /// Handles dropped items, extracting the first valid file URL.
    static func handleDrop(providers: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            completion(nil)
            return
        }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
             DispatchQueue.main.async {
                 if let url = url {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                         completion(nil)
                    } else {
                         completion(url)
                    }
                 } else {
                    print("Error loading dropped item: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                 }
             }
         }
    }


    /// Presents an Open Panel for selecting a single video file.
    static func selectFile(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if url.startAccessingSecurityScopedResource() {
                 if FileUtilities.isVideoFile(url) {
                    completion(url)
                 } else {
                    url.stopAccessingSecurityScopedResource()
                    completion(nil)
                 }
            } else {
                 if FileUtilities.isVideoFile(url) {
                     print("Warning: Could not start security-scoped access for \(url.lastPathComponent). Conversion might fail.")
                     completion(url)
                 } else {
                     completion(nil)
                 }
            }
        } else {
            completion(nil)
        }
    }

    /// Retrieves the size of the file at the given URL.
    /// - Parameter url: The URL of the file.
    /// - Returns: The file size in bytes as `Int64`, or `nil` if the size cannot be determined.
    static func getFileSize(url: URL) -> Int64? {
        do {
            // Ensure we have security access if needed, though this should ideally be handled by the caller
            // For files already accessed (like input) or just created (output in sandbox), direct access might be fine.
            // If this fails for the input file, it means security scope wasn't properly maintained.
            let isReachable = try url.checkResourceIsReachable()
            guard isReachable else {
                print("File not reachable for size check: \(url.path)")
                return nil
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            print("Error getting file size for \(url.path): \(error)")
            return nil
        }
    }

    /// Formats a byte count into a human-readable string (e.g., KB, MB, GB).
    /// - Parameter bytes: The number of bytes.
    /// - Returns: A human-readable string representation of the byte count.
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB] // Adjust units as needed
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
