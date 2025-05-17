import Foundation
import AppKit
import UniformTypeIdentifiers

struct FileUtilities {

    static func isVideoFile(_ url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
              let type = resourceValues.contentType else {
            let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
            return videoExtensions.contains(url.pathExtension.lowercased())
        }
        return type.conforms(to: .video) || type.conforms(to: .movie)
    }

    static func selectFiles(completion: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            var validVideoURLsWithAccess: [URL] = []
            for url in panel.urls {
                if url.startAccessingSecurityScopedResource() { // Start access
                    if FileUtilities.isVideoFile(url) {
                        validVideoURLsWithAccess.append(url) // Keep access started
                    } else {
                        url.stopAccessingSecurityScopedResource() // Not a video, stop access
                        print("'\(url.lastPathComponent)' is not a video.")
                    }
                } else {
                    // If couldn't start access, but it IS a video, add it but warn user.
                    if FileUtilities.isVideoFile(url) {
                        print("Warning: Could not start security-scoped access for \(url.lastPathComponent) during selection. It might fail later.")
                        validVideoURLsWithAccess.append(url) // Add, but it has no access started
                    }
                }
            }
            completion(validVideoURLsWithAccess.isEmpty ? nil : validVideoURLsWithAccess)
        } else {
            completion(nil)
        }
    }

    static func chooseOutputDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Output Directory"
        if panel.runModal() == .OK { return panel.url }
        return nil
    }

    static func handleDrop(providers: [NSItemProvider], completion: @escaping ([URL]?) -> Void) {
        var processedFileURLsWithAccess: [URL] = []
        let dispatchGroup = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                dispatchGroup.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { dispatchGroup.leave() }
                    guard let droppedURL = url else {
                        if let err = error { print("Error loading dropped item: \(err.localizedDescription)") }
                        return
                    }

                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: droppedURL.path, isDirectory: &isDir) {
                        if isDir.boolValue {
                            guard droppedURL.startAccessingSecurityScopedResource() else {
                                print("Could not start security access for dropped folder: \(droppedURL.lastPathComponent)")
                                return
                            }
                            defer { droppedURL.stopAccessingSecurityScopedResource() }

                            do {
                                let contents = try FileManager.default.contentsOfDirectory(
                                    at: droppedURL, includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
                                    options: .skipsHiddenFiles
                                )
                                for itemURL in contents {
                                    if FileUtilities.isVideoFile(itemURL) {
                                        if itemURL.startAccessingSecurityScopedResource() { // Start access for child item
                                            processedFileURLsWithAccess.append(itemURL)
                                        } else {
                                            print("Dropped folder item: Could not start security access for \(itemURL.lastPathComponent)")
                                        }
                                    }
                                }
                            } catch { print("Error enumerating dropped directory \(droppedURL.path): \(error)") }
                        } else { // Single file
                            if FileUtilities.isVideoFile(droppedURL) {
                                if droppedURL.startAccessingSecurityScopedResource() { // Start access for single dropped file
                                    processedFileURLsWithAccess.append(droppedURL)
                                } else {
                                    print("Dropped file: Could not start security access for \(droppedURL.lastPathComponent)")
                                }
                            }
                        }
                    }
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion(processedFileURLsWithAccess.isEmpty ? nil : processedFileURLsWithAccess)
        }
    }

    static func getFileSize(url: URL) -> Int64? {
        var needsToStopAccess = false
        let isInitiallyReachable = (try? url.checkResourceIsReachable()) == true
        var canCurrentlyAccess = isInitiallyReachable

        if !isInitiallyReachable {
            if url.startAccessingSecurityScopedResource() {
                needsToStopAccess = true
                canCurrentlyAccess = true
            }
        }
        guard canCurrentlyAccess else {
            print("File not reachable for size check & couldn't gain access: \(url.path)")
            return nil
        }
        defer { if needsToStopAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            return try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        } catch {
            print("Error getting file size for \(url.path): \(error)")
            return nil
        }
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]; formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
