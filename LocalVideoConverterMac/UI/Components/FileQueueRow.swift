import SwiftUI

struct FileQueueRow: View {
    let item: FileQueueItem
    @ObservedObject var converter: VideoConverter
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if converter.mode == .audioExtraction {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .onTapGesture { withAnimation { isExpanded.toggle() } }
                        .frame(width: 20)
                }
                
                VStack(alignment: .leading) {
                    Text(item.inputURL.lastPathComponent)
                        .font(.headline)
                        .truncationMode(.middle)
                        .lineLimit(1)
                    
                    if let msg = item.successMessage {
                        Text(msg).font(.caption).foregroundColor(.green)
                    } else if let err = item.errorMessage {
                        Text(err).font(.caption).foregroundColor(.red)
                    } else {
                        Text(item.status.displayName).font(.caption).foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status Icons & Buttons
                if item.status == .converting {
                    HStack(spacing: 8) {
                        ProgressView(value: item.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 60)
                        
                        Text("\(Int(item.progress * 100))%")
                            .font(.caption).monospacedDigit()
                        
                        Text(item.elapsedTime)
                            .font(.caption).monospacedDigit().foregroundColor(.secondary)
                    }
                } else if item.status == .completed {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Button {
                            converter.revealInFinder(item: item)
                        } label: {
                            Image(systemName: "magnifyingglass.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                    }
                } else if item.status == .failed {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
            
            // Expanded Audio View
            if converter.mode == .audioExtraction && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Select tracks to extract:").font(.caption2).foregroundColor(.secondary)
                    
                    ForEach(item.audioTracks) { track in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { track.isSelected },
                                set: { _ in converter.toggleTrackSelection(itemID: item.id, trackID: track.id) }
                            )).labelsHidden()
                            
                            Text("Track \(track.index + 1)").font(.system(size: 11, weight: .bold)).frame(width: 50, alignment: .leading)
                            
                            TextField("Filename", text: Binding(
                                get: { track.customName },
                                set: { converter.updateTrackName(itemID: item.id, trackID: track.id, newName: $0) }
                            )).textFieldStyle(RoundedBorderTextFieldStyle()).font(.system(size: 11))
                        }
                    }
                    if item.audioTracks.filter({ $0.isSelected }).count > 1 {
                        Divider()
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { item.mergeSelectedTracks },
                                set: { _ in converter.toggleMerge(itemID: item.id) }
                            )).labelsHidden()
                            Text("Merge Selected").font(.system(size: 11, weight: .bold))
                            TextField("Merged Filename", text: Binding(
                                get: { item.mergedTrackName },
                                set: { converter.updateMergedName(itemID: item.id, name: $0) }
                            )).textFieldStyle(RoundedBorderTextFieldStyle()).font(.system(size: 11))
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.bottom, 5)
            }
        }
    }
}//
//  FileQueueRow.swift
//  LocalVideoConverterMac
//
//  Created by Luis Flacke on 9/12/25.
//

