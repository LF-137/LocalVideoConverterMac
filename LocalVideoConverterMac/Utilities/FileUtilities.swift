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
                // For files selected via OpenPanel, we technically don't need to manually
                // start accessing if we use them immediately, but for a queue system,
                // we should treat them as security scoped to be safe.
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
}
