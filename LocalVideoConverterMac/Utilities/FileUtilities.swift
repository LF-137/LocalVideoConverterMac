import Foundation
import AppKit

/// Utility struct for file-related operations in the video converter app.
struct FileUtilities {

    /// Presents a Save Panel to the user for choosing an output URL for the converted video.
    ///
    /// - Parameter defaultURL: The default URL to suggest in the Save Panel (e.g., based on the input video name).
    /// - Returns: An optional URL representing the user-selected output URL, or nil if the user cancels.
    static func chooseOutputURL(defaultURL: URL) -> URL? {
        let savePanel = NSSavePanel() // Create a new Save Panel
        savePanel.allowedContentTypes = [.mpeg4Movie, .movie, .quickTimeMovie, .avi] // Set allowed file types for saving
        savePanel.directoryURL = defaultURL.deletingLastPathComponent() // Set default directory to input video's directory
        savePanel.nameFieldStringValue = defaultURL.lastPathComponent // Set default filename to input video's name

        // Present the Save Panel modally and check if the user clicked "OK"
        if savePanel.runModal() == .OK {
            return savePanel.url // Return the selected URL if user clicked OK
        }
        return nil // Return nil if user cancelled the Save Panel
    }


    /// Checks if a given URL points to a video file based on its file extension.
    ///
    /// - Parameter url: The URL of the file to check.
    /// - Returns: `true` if the URL has a video file extension (mp4, mov, avi, mkv), `false` otherwise.
    static func isVideoFile(_ url: URL) -> Bool {
        let allowedExtensions = ["mp4", "mov", "avi", "mkv"] // Array of allowed video file extensions
        return allowedExtensions.contains(url.pathExtension.lowercased()) // Check if the URL's extension is in the allowed list (case-insensitive)
    }


    /// Handles dropped items from a drag-and-drop operation, attempting to load a file URL.
    ///
    /// - Parameters:
    ///   - providers: An array of `NSItemProvider` objects representing the dropped items.
    ///   - completion: A completion handler closure that is called with the loaded file URL (or nil if loading fails).
    static func handleDrop(providers: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        guard let provider = providers.first else { // Get the first item provider from the array
            completion(nil) // If no provider, call completion handler with nil (no URL loaded)
            return
        }

        // Load the item as a file URL asynchronously
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            // Handle the loaded item in the completion handler
            if let url = item as? URL {
                completion(url) // If item is a URL, call completion with the URL
            } else if let data = item as? Data, // If item is Data (fallback for file URLs)
                      let url = URL(dataRepresentation: data, relativeTo: nil) { // Try to create URL from Data
                completion(url) // Call completion with the URL created from Data
            } else {
                completion(nil) // If item is not a URL or Data representing a URL, call completion with nil
            }
        }
    }


    /// Presents an Open Panel to the user for selecting a video file from Finder.
    ///
    /// - Parameter completion: A completion handler closure that is called with the selected file URL (or nil if selection fails or is cancelled).
    static func selectFile(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel() // Create a new Open Panel
        panel.allowedContentTypes = [.movie] // Set allowed content types to movie files
        panel.allowsMultipleSelection = false // Allow only single file selection
        panel.canChooseFiles = true // Allow file selection
        panel.canChooseDirectories = false // Prevent directory selection

        // Run the Open Panel modally and check if the user clicked "OK"
        if panel.runModal() == .OK, let url = panel.url { // If user clicked OK and a URL is available
            // Check if the selected URL is a video file and start accessing security-scoped resource
            if FileUtilities.isVideoFile(url), url.startAccessingSecurityScopedResource() {
                completion(url) // Call completion handler with the selected URL if it's a video file and security access starts
            } else {
                url.stopAccessingSecurityScopedResource()
                completion(nil) // Call completion handler with nil if it's not a video file or security access fails
            }
        } else {
            completion(nil) // Call completion handler with nil if user cancelled or no URL selected
        }
    }
}
