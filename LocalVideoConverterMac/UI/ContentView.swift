import SwiftUI

/// The main view for the video converter application.
/// Handles user interaction for file selection, settings access, and initiating conversions.
/// Observes `VideoConverter` for state changes (progress, errors, settings).
struct ContentView: View {
    // MARK: - Observed Object (ViewModel)

    /// The ViewModel that manages conversion logic, state, and settings.
    @StateObject private var converter = VideoConverter()

    // MARK: - Local UI State

    /// Tracks whether a file is being dragged over the drop area.
    @State private var isDragging = false
    /// Controls the presentation of the SettingsView sheet.
    @State private var showSettings = false

    // MARK: - View Body

    var body: some View {
        VStack(spacing: 20) { // Main vertical layout
            // MARK: Drag and Drop Area
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDragging ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDragging ? Color.blue : Color.gray, lineWidth: 2))

                if let videoURL = converter.inputURL {
                    // Display selected filename (using state from VideoConverter)
                    Text("Selected File: \(videoURL.lastPathComponent)")
                        .padding(.horizontal)
                } else {
                    Text("Drag and drop a video file here\nor use 'Select File'")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                FileUtilities.handleDrop(providers: providers) { url in
                    // Let the ViewModel handle the dropped file
                    converter.setInputURL(url)
                }
                return true // Indicate drop handling success
            }
            .padding(.horizontal) // Padding around Drag and Drop Area

            // MARK: - Messages Display Area
            VStack(alignment: .leading) {
                // Display error message from ViewModel
                if let errorMessage = converter.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                // Display success message from ViewModel
                if let successMessage = converter.successMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                }
            }
            .frame(minHeight: 30) // Ensure space for messages

            // MARK: - File Selection Buttons
            HStack {
                Button {
                    FileUtilities.selectFile { url in
                        // Let the ViewModel handle the selected file
                        converter.setInputURL(url)
                    }
                } label: {
                    Text("Select File")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                // Show "Clear" button if a video is selected in the ViewModel
                if converter.inputURL != nil {
                    Button {
                        // Ask ViewModel to clear the selection
                        converter.clearInput()
                    } label: {
                        Text("Clear")
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.leading, 5)
                }
            }
            .padding(.horizontal)

            // MARK: - Settings and Convert Buttons
            HStack {
                // Settings Button
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gear")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                // Convert Button
                Button {
                    // Ask ViewModel to start conversion using its current state
                    converter.startConversion()
                } label: {
                    if converter.isConverting {
                        ProgressView(value: converter.progress)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(2) // Add padding so the circle isn't cut off
                    } else {
                        Label("Convert", systemImage: "film.stack")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                // Disable button if no video selected or conversion is running
                .disabled(converter.inputURL == nil || converter.isConverting)
                .padding(.leading, 5)

            }
            .padding(.horizontal)

            // MARK: Cancel Button
            // Show Cancel button only during conversion
            if converter.isConverting {
                Button {
                    converter.cancelConversion()
                } label: {
                    Label("Cancel Conversion", systemImage: "xmark.circle.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 5) // Add some space above cancel button
            }

            Spacer() // Pushes content to the top
        }
        .padding() // Padding for the entire ContentView
        // Present SettingsView as a sheet
        .sheet(isPresented: $showSettings) {
            // Pass bindings to the ViewModel's settings properties
            SettingsView(
                outputFormat: $converter.outputFormat,
                videoQuality: $converter.videoQuality,
                audioCodec: $converter.audioCodec,
                videoCodec: $converter.videoCodec
            )
        }
    }
}

// MARK: - Preview Provider

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
