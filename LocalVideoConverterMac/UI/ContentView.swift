import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var converter = VideoConverter()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Header
            HStack {
                Text("Video Converter")
                    .font(.headline)
                Spacer()
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // MARK: - Main Area (Queue or Empty State)
            ZStack {
                if converter.fileQueue.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Drag & Drop videos here")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("or click Add Files below")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(converter.fileQueue) { item in
                            FileQueueRow(item: item)
                        }
                        .onDelete(perform: converter.removeItems)
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 300)
            .onDrop(of: [.fileURL], delegate: VideoDropDelegate(converter: converter))
            
            Divider()

            // MARK: - Footer Controls
            VStack(spacing: 12) {
                if let error = converter.globalErrorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                if !converter.overallProgressMessage.isEmpty {
                    Text(converter.overallProgressMessage)
                        .font(.caption)
                        .monospacedDigit()
                }

                HStack {
                    Button {
                        FileUtilities.selectFiles { urls in
                            if let urls = urls { converter.addFiles(urls: urls) }
                        }
                    } label: {
                        Label("Add Files", systemImage: "plus")
                    }
                    .disabled(converter.isBatchConverting)
                    
                    if !converter.fileQueue.isEmpty {
                        Button("Clear") { converter.clearQueue() }
                        .disabled(converter.isBatchConverting)
                    }

                    Spacer()

                    if converter.isBatchConverting {
                        Button(role: .destructive) {
                            converter.cancelBatch()
                        } label: {
                            Text("Cancel Batch")
                        }
                    } else {
                        Button {
                            converter.startBatch()
                        } label: {
                            Text("Start Conversion")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(converter.fileQueue.isEmpty)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                outputFormat: $converter.outputFormat,
                videoQuality: $converter.videoQuality,
                audioCodec: $converter.audioCodec,
                videoCodec: $converter.videoCodec
            )
        }
    }
}

// MARK: - Drag & Drop Delegate
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
}

// MARK: - Row View
struct FileQueueRow: View {
    let item: FileQueueItem
    
    var body: some View {
        HStack {
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
            
            if item.status == .converting {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
                Text("\(Int(item.progress * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 35, alignment: .trailing)
            } else if item.status == .completed {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            } else if item.status == .failed {
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
