import SwiftUI
import AppKit

struct ContentView: View {
    @State private var videoURL: URL?
    @State private var isDragging = false
    @State private var errorMessage: String?
    @State private var isConverting = false

    // Settings state
    @State private var outputFormat = "mp4"
    @State private var videoQuality = "high"
    @State private var audioCodec = "aac"
    @State private var showSettings = false

    var body: some View {
        VStack {
            // MARK: Drag-and-Drop Area
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDragging ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isDragging ? Color.blue : Color.gray, lineWidth: 2)
                    )
                
                if let videoURL = videoURL {
                    Text("Selected File: \(videoURL.lastPathComponent)")
                } else {
                    Text("Drag and drop a video file here")
                        .foregroundColor(.gray)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
                return true
            }
            .padding()

            // MARK: Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            // MARK: Select File Button
            Button(action: selectFile) {
                Text("Select File from Finder")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            // MARK: Clear Selection Button
            if videoURL != nil {
                Button(action: {
                    videoURL = nil
                    errorMessage = nil
                }) {
                    Text("Clear Selection")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }

            // MARK: Settings Button
            Button(action: { showSettings = true }) {
                Text("Settings")
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .sheet(isPresented: $showSettings) {
                SettingsView(outputFormat: $outputFormat,
                             videoQuality: $videoQuality,
                             audioCodec: $audioCodec)
            }

            // MARK: Convert Button
            Button(action: convertVideo) {
                if isConverting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.white)
                } else {
                    Text("Convert Video")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.green)
            .cornerRadius(10)
            .disabled(videoURL == nil || isConverting)
        }
        .padding()
    }

    // MARK: - Drag-and-Drop Handler
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            if let url = item as? URL {
                DispatchQueue.main.async {
                    if isVideoFile(url) {
                        self.videoURL = url
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Invalid file type. Please drop a video file."
                    }
                }
            } else if let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    if isVideoFile(url) {
                        self.videoURL = url
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Invalid file type. Please drop a video file."
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load file."
                }
            }
        }
        return true
    }

    // MARK: - File Selection Using NSOpenPanel
    func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if isVideoFile(url) {
                // Attempt to gain secure access (required in sandbox mode)
                if url.startAccessingSecurityScopedResource() {
                    self.videoURL = url
                    self.errorMessage = nil
                    // Note: Do not call stopAccessingSecurityScopedResource() here,
                    // since you'll use the URL later during conversion.
                } else {
                    self.errorMessage = "Unable to access selected file due to sandbox restrictions."
                }
            } else {
                self.errorMessage = "Invalid file type. Please select a video file."
            }
        }
    }

    // MARK: - Validate Video File Extension
    func isVideoFile(_ url: URL) -> Bool {
        let allowedExtensions = ["mp4", "mov", "avi", "mkv"]
        return allowedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Let the User Choose the Output File Location
    func chooseOutputURL(defaultURL: URL) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.directoryURL = defaultURL.deletingLastPathComponent()
        savePanel.nameFieldStringValue = defaultURL.lastPathComponent
        if savePanel.runModal() == .OK {
            return savePanel.url
        }
        return nil
    }

    // MARK: - Convert Video Using FFmpeg
    func convertVideo() {
        guard let videoURL = videoURL else { return }
        isConverting = true

        // Instead of writing next to the input file (which might be in a restricted location),
        // ask the user where to save the converted video.
        let defaultOutputURL = videoURL.deletingPathExtension().appendingPathExtension(outputFormat)
        guard let outputURL = chooseOutputURL(defaultURL: defaultOutputURL) else {
            self.errorMessage = "No output file location selected."
            self.isConverting = false
            return
        }

        // Build FFmpeg arguments.
        // The "-y" flag forces overwrite if the file already exists.
        var arguments = ["-y", "-i", videoURL.path]
        switch videoQuality {
        case "high":
            arguments.append(contentsOf: ["-crf", "18"])
        case "medium":
            arguments.append(contentsOf: ["-crf", "23"])
        case "low":
            arguments.append(contentsOf: ["-crf", "28"])
        default:
            break
        }
        switch audioCodec {
        case "aac":
            arguments.append(contentsOf: ["-c:a", "aac"])
        case "mp3":
            arguments.append(contentsOf: ["-c:a", "libmp3lame"])
        case "none":
            arguments.append(contentsOf: ["-an"])
        default:
            break
        }
        arguments.append(outputURL.path)

        // Attempt secure-scoped access.
        guard videoURL.startAccessingSecurityScopedResource() else {
            self.errorMessage = "Unable to access security scoped resource."
            isConverting = false
            return
        }

        let task = Process()

        // Locate FFmpeg inside your app bundle.
        if let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            task.launchPath = ffmpegPath
        } else {
            self.errorMessage = "FFmpeg not found in bundle."
            isConverting = false
            videoURL.stopAccessingSecurityScopedResource()
            return
        }

        task.arguments = arguments

        // Capture FFmpeg errors.
        let errorPipe = Pipe()
        task.standardError = errorPipe
        task.standardOutput = Pipe()

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.isConverting = false
                videoURL.stopAccessingSecurityScopedResource()
                
                // Check if the output file exists.
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    self.errorMessage = nil
                    print("Conversion complete: \(outputURL.path)")
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                } else {
                    // Read any FFmpeg error output.
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    self.errorMessage = "FFmpeg error: \(errorString)"
                    print("FFmpeg error: \(errorString)")
                }
            }
        }

        do {
            try task.run()
        } catch {
            self.isConverting = false
            self.errorMessage = "Failed to convert video: \(error)"
            videoURL.stopAccessingSecurityScopedResource()
            print("Failed to convert video: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
