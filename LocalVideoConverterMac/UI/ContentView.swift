import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ContentView: View {
    @StateObject private var converter = VideoConverter()
    @State private var showSettings = false
    @State private var notificationDelegate = NotificationDelegate()
    
    // MARK: - Persistent Settings
    @AppStorage("conversionMode") private var savedMode: ConversionMode = .videoConversion
    @AppStorage("audioExportFormat") private var savedAudioFormat: AudioExportFormat = .mp3
    
    // Video Settings Persistence
    @AppStorage("outputFormat") private var savedOutputFormat: OutputFormat = .mp4
    @AppStorage("videoCodec") private var savedVideoCodec: VideoCodec = .h264
    @AppStorage("videoQuality") private var savedVideoQuality: VideoQuality = .medium
    @AppStorage("audioCodec") private var savedAudioCodec: AudioCodec = .aac

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Header & Mode Selection
            VStack(spacing: 10) {
                HStack {
                    Text("Batch Converter")
                        .font(.headline)
                    Spacer()
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                
                Picker("Mode", selection: $savedMode) {
                    ForEach(ConversionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(converter.isBatchConverting || !converter.fileQueue.isEmpty)
                // FIX: Updated syntax for macOS 14+
                .onChange(of: savedMode) { _, newValue in
                    converter.mode = newValue
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // MARK: - Settings Info Bar
            if savedMode == .audioExtraction {
                HStack {
                    Text("Export Format:")
                    Picker("", selection: $savedAudioFormat) {
                        ForEach(AudioExportFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .frame(width: 100)
                    // FIX: Updated syntax for macOS 14+
                    .onChange(of: savedAudioFormat) { _, newValue in
                        converter.audioExportFormat = newValue
                    }
                    
                    Spacer()
                    Text("Expand items below to select tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
                .background(Color(NSColor.controlBackgroundColor))
            }

            // MARK: - Main Area
            ZStack {
                if converter.fileQueue.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Drag & Drop videos here")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(converter.fileQueue) { item in
                            FileQueueRow(item: item, converter: converter)
                        }
                        .onDelete(perform: converter.removeItems)
                        .onMove(perform: converter.moveItems)
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .onDrop(of: [.fileURL], delegate: VideoDropDelegate(converter: converter))
            
            Divider()

            // MARK: - Footer Controls
            VStack(spacing: 12) {
                if let error = converter.globalErrorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                if !converter.overallProgressMessage.isEmpty {
                    Text(converter.overallProgressMessage).font(.caption).monospacedDigit()
                }

                HStack {
                    Button {
                        FileUtilities.selectFiles { urls in
                            if let urls = urls { converter.addFiles(urls: urls) }
                        }
                    } label: { Label("Add Files", systemImage: "plus") }
                    .disabled(converter.isBatchConverting)
                    
                    if !converter.fileQueue.isEmpty {
                        Button("Clear All") { converter.clearQueue() }
                        .disabled(converter.isBatchConverting)
                        
                        if converter.fileQueue.contains(where: { $0.status == .completed }) {
                             Button("Clear Done") {
                                 let offsets = IndexSet(converter.fileQueue.indices.filter { converter.fileQueue[$0].status == .completed })
                                 converter.removeItems(at: offsets)
                             }
                             .disabled(converter.isBatchConverting)
                        }
                    }

                    Spacer()

                    if converter.isBatchConverting {
                        Button(role: .destructive) { converter.cancelBatch() } label: { Text("Cancel") }
                    } else {
                        Button {
                            converter.startBatch()
                        } label: {
                            Text(savedMode == .videoConversion ? "Start Video Conversion" : "Extract Audio")
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
                outputFormat: $savedOutputFormat,
                videoQuality: $savedVideoQuality,
                audioCodec: $savedAudioCodec,
                videoCodec: $savedVideoCodec
            )
            .onDisappear {
                converter.outputFormat = savedOutputFormat
                converter.videoQuality = savedVideoQuality
                converter.audioCodec = savedAudioCodec
                converter.videoCodec = savedVideoCodec
            }
        }
        .onAppear {
            converter.mode = savedMode
            converter.audioExportFormat = savedAudioFormat
            converter.outputFormat = savedOutputFormat
            converter.videoQuality = savedVideoQuality
            converter.audioCodec = savedAudioCodec
            converter.videoCodec = savedVideoCodec
            
            // 1. Assign Delegate
            UNUserNotificationCenter.current().delegate = notificationDelegate
            
            // 2. Request Permissions
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Drop Delegate
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
                if let urlData = data as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    if FileUtilities.isVideoFile(url) { urls.append(url) }
                }
            }
        }
        group.notify(queue: .main) { converter.addFiles(urls: urls) }
        return true
    }
}

// MARK: - Row View
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
                    HStack(spacing: 5) {
                        ProgressView(value: item.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 60)
                        Text("\(Int(item.progress * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
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
}
