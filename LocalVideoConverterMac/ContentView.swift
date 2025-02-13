import SwiftUI

struct ContentView: View {
    @State private var videoURL: URL?
    @State private var isDragging = false

    // Settings state
    @State private var outputFormat = "mp4"
    @State private var videoQuality = "high"
    @State private var audioCodec = "aac"
    @State private var videoCodec = "h264"
    @State private var showSettings = false

    @ObservedObject private var converter = VideoConverter() // Use the VideoConverter

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
                FileUtilities.handleDrop(providers: providers) { url in
                    DispatchQueue.main.async {
                        if let url = url, FileUtilities.isVideoFile(url) {
                               self.videoURL = url
                               self.converter.errorMessage = nil //Clear previous errors
                           } else {
                               self.converter.errorMessage = "Invalid file type or failed to load."
                           }
                    }
                }

                return true
            }
            .padding()

            // MARK: Error Message
            if let errorMessage = converter.errorMessage { // Use converter's errorMessage
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            // MARK: Select File Button
            Button(action: {
                FileUtilities.selectFile { url in
                    DispatchQueue.main.async {
                        self.videoURL = url
                    }
                }
            }) {
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
                    converter.errorMessage = nil // Clear error message
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
                             audioCodec: $audioCodec,
                             videoCodec: $videoCodec)
            }

            // MARK: Convert Button
            Button(action: {
                if let videoURL = videoURL,
                   let outputURL = FileUtilities.chooseOutputURL(defaultURL: videoURL.deletingPathExtension().appendingPathExtension(outputFormat)) {
                    converter.convertVideo(inputURL: videoURL, outputURL: outputURL, outputFormat: outputFormat, videoCodec: videoCodec, videoQuality: videoQuality, audioCodec: audioCodec)
                } else {
                    converter.errorMessage = "Please select a valid input video and output location."
                }
            }) {
                if converter.isConverting {
                    ProgressView(value: converter.progress) // Use converter's progress
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
            .disabled(videoURL == nil || converter.isConverting) // Use converter's isConverting

            // MARK: Cancel Button
            if converter.isConverting {
                Button(action: {
                    converter.cancelConversion()
                }) {
                    Text("Cancel")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }

        }
        .padding()
    }
}
