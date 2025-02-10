import SwiftUI

struct ContentView: View {
    @State private var videoURL: URL?
    @State private var isDragging = false
    @State private var errorMessage: String?
    @State private var isConverting = false

    // state variables for settings
    @State private var outputFormat = "mp4"
    @State private var videoQuality = "high"
    @State private var audioCodec = "aac"
    @State private var showSettings = false
    
    
    var body: some View {
        VStack {
            // Drag-and-Drop Area
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

            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            // Search Button
            Button(action: selectFile) {
                Text("Select File from Finder")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            // Clear Button
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
            
            // Settings Button
            Button(action: {
                showSettings = true
            }) {
                Text("Settings")
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .sheet(isPresented: $showSettings) {
                SettingsView(outputFormat: $outputFormat, videoQuality: $videoQuality, audioCodec: $audioCodec)
            }
            
            // Convert Button
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

    // Handle file drop
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            if let url = item as? URL {
                DispatchQueue.main.async {
                    if isVideoFile(url) {
                        videoURL = url
                        errorMessage = nil
                    } else {
                        errorMessage = "Invalid file type. Please drop a video file."
                    }
                }
            }
        }
        return true
    }

    // Handle file selection from Finder
    func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        if panel.runModal() == .OK, let url = panel.url {
            if isVideoFile(url) {
                videoURL = url
                errorMessage = nil
            } else {
                errorMessage = "Invalid file type. Please select a video file."
            }
        }
    }

    // Validate if the file is a video
    func isVideoFile(_ url: URL) -> Bool {
        let allowedExtensions = ["mp4", "mov", "avi", "mkv"]
        return allowedExtensions.contains(url.pathExtension.lowercased())
    }

    // Convert video using FFmpeg
    func convertVideo() {
        guard let videoURL = videoURL else { return }
        isConverting = true

        // Set the output file path
        let outputURL = videoURL.deletingPathExtension().appendingPathExtension(outputFormat)

        // Build FFmpeg arguments based on settings
        var arguments = ["-i", videoURL.path]

        // Video quality settings
        switch videoQuality {
        case "high":
            arguments.append(contentsOf: ["-crf", "18"]) // High quality
        case "medium":
            arguments.append(contentsOf: ["-crf", "23"]) // Medium quality
        case "low":
            arguments.append(contentsOf: ["-crf", "28"]) // Low quality
        default:
            break
        }

        // Audio codec settings
        switch audioCodec {
        case "aac":
            arguments.append(contentsOf: ["-c:a", "aac"]) // AAC audio
        case "mp3":
            arguments.append(contentsOf: ["-c:a", "libmp3lame"]) // MP3 audio
        case "none":
            arguments.append(contentsOf: ["-an"]) // No audio
        default:
            break
        }

        arguments.append(outputURL.path)

        // Run FFmpeg
        
        
        let task = Process()
        
        if let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            task.launchPath = ffmpegPath
        } else {
            print("FFmpeg not found in bundle")
            return
        }
        
        // out commented
        //task.launchPath = "/opt/homebrew/bin/ffmpeg" // Set the FFmpeg path here
        task.arguments = arguments

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                isConverting = false
                print("Conversion complete: \(outputURL.path)")
                NSWorkspace.shared.activateFileViewerSelecting([outputURL]) // Open the output directory in Finder
            }
        }

        do {
            try task.run()
        } catch {
            isConverting = false
            print("Failed to convert video: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
