import SwiftUI
import UniformTypeIdentifiers

struct VideoDropDelegate: DropDelegate {
    var converter: VideoConverter
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                defer { group.leave() }
                if let urlData = data as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    if FileUtilities.isVideoFile(url) {
                        urls.append(url)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            converter.addFiles(urls: urls)
        }
        return true
    }
}//
//  VideoDropDelegate.swift
//  LocalVideoConverterMac
//
//  Created by Luis Flacke on 9/12/25.
//

