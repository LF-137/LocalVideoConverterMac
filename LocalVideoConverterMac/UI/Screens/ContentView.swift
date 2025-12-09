import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var converter = VideoConverter()
    @State private var showSettings = false
    
    // MARK: - Persistent Settings
    @AppStorage("conversionMode") private var savedMode: ConversionMode = .videoConversion
    @AppStorage("audioExportFormat") private var savedAudioFormat: AudioExportFormat = .mp3
    @AppStorage("outputFormat") private var savedOutputFormat: OutputFormat = .mp4
    @AppStorage("videoCodec") private var savedVideoCodec: VideoCodec = .h264
    @AppStorage("videoQuality") private var savedVideoQuality: VideoQuality = .medium
    @AppStorage("audioCodec") private var savedAudioCodec: AudioCodec = .aac
    
    // NEW: Persistent Encoding Preference
    @AppStorage("encodingType") private var savedEncodingType: EncodingType = .hardware

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Header & Mode
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
                .onChange(of: savedMode) { _, newValue in converter.mode = newValue }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // MARK: - Sub Header
            if savedMode == .audioExtraction {
                HStack {
                    Text("Export Format:")
                    Picker("", selection: $savedAudioFormat) {
                        ForEach(AudioExportFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .frame(width: 100)
                    .onChange(of: savedAudioFormat) { _, newValue in converter.audioExportFormat = newValue }
                    
                    Spacer()
                    Text("Expand items to select tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
                .background(Color(NSColor.controlBackgroundColor))
            }

            // MARK: - Main List
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

            // MARK: - Footer
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
                videoCodec: $savedVideoCodec,
                encodingType: $savedEncodingType // NEW Pass binding
            )
            .onDisappear {
                converter.outputFormat = savedOutputFormat
                converter.videoQuality = savedVideoQuality
                converter.audioCodec = savedAudioCodec
                converter.videoCodec = savedVideoCodec
                converter.encodingType = savedEncodingType // Update converter
            }
        }
        .onAppear {
            converter.mode = savedMode
            converter.audioExportFormat = savedAudioFormat
            converter.outputFormat = savedOutputFormat
            converter.videoQuality = savedVideoQuality
            converter.audioCodec = savedAudioCodec
            converter.videoCodec = savedVideoCodec
            converter.encodingType = savedEncodingType // Load setting
            
            NotificationManager.shared.requestPermission()
        }
    }
}
