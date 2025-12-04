import Foundation
import AppKit
import UniformTypeIdentifiers

struct FileUtilities {

    static let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm", "ts", "mts"]

    static func isVideoFile(_ url: URL) -> Bool {
        // 1. Check extension
        if videoExtensions.contains(url.pathExtension.lowercased()) { return true }
        
        // 2. Check UTType
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let type = resourceValues.contentType {
            return type.conforms(to: .video) || type.conforms(to: .movie)
        }
        return false
    }

    static func selectFiles(completion: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        panel.begin { response in
            guard response == .OK else {
                completion(nil)
                return
            }
            
            var validURLs: [URL] = []
            for url in panel.urls {
                if isVideoFile(url) {
                    validURLs.append(url)
                }
            }
            completion(validURLs.isEmpty ? nil : validURLs)
        }
    }

    static func chooseOutputDirectory(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Output Folder"
        
        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }

    static func getFileSize(url: URL) -> Int64? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
            return nil
        }
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - New Logic for Unique Filenames
    
    /// Generates a unique URL. If 'Video.mp4' exists, returns 'Video (1).mp4', etc.
    static func generateUniqueOutputPath(from idealURL: URL) -> URL {
        var counter = 1
        var newURL = idealURL
        
        // While a file exists at the generated path, keep incrementing the number
        while FileManager.default.fileExists(atPath: newURL.path) {
            let folder = idealURL.deletingLastPathComponent()
            let originalName = idealURL.deletingPathExtension().lastPathComponent
            let ext = idealURL.pathExtension
            
            // Format: "Filename (1).ext"
            let newName = "\(originalName) (\(counter))"
            newURL = folder.appendingPathComponent(newName).appendingPathExtension(ext)
            
            counter += 1
        }
        
        return newURL
    }
}
