// FileUtilities.swift
import Foundation
import AppKit

struct FileUtilities {
    static func chooseOutputURL(defaultURL: URL) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie, .movie, .quickTimeMovie, .avi]
        savePanel.directoryURL = defaultURL.deletingLastPathComponent()
        savePanel.nameFieldStringValue = defaultURL.lastPathComponent
        if savePanel.runModal() == .OK {
            return savePanel.url
        }
        return nil
    }

    static func isVideoFile(_ url: URL) -> Bool {
        let allowedExtensions = ["mp4", "mov", "avi", "mkv"]
        return allowedExtensions.contains(url.pathExtension.lowercased())
    }
     static func handleDrop(providers: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        guard let provider = providers.first else {
            completion(nil)
            return
        }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            if let url = item as? URL {
                completion(url)
            } else if let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
    static func selectFile(completion: @escaping (URL?) -> Void) {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.movie]
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = true
            panel.canChooseDirectories = false

            if panel.runModal() == .OK, let url = panel.url {
                if FileUtilities.isVideoFile(url), url.startAccessingSecurityScopedResource() {
                    completion(url)
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
}
