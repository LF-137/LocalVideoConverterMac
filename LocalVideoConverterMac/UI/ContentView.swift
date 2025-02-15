import SwiftUI

struct ContentView: View {
    // MARK: - State Variables - For managing UI state and data

    @State private var videoURL: URL?         // URL of the selected video file
    @State private var isDragging = false    // Tracks drag operation over drag-and-drop area

    // MARK: - Settings State (for video conversion) - Settings that control the conversion process

    @State private var outputFormat = "mp4"      // Output video format
    @State private var videoQuality = "low"     // Video quality setting (maps to CRF)
    @State private var audioCodec = "aac"        // Audio codec setting
    @State private var videoCodec = "h264"        // Video codec setting
    @State private var showSettings = false     // Controls presentation of SettingsView

    // MARK: - UI State for Messages and Progress - State for displaying messages and progress in the UI

    @State private var errorMessage: String? = nil    // Error message to display
    @State private var successMessage: String? = nil   // Success message to display

    // MARK: - Observed Object - For handling video conversion logic

    @ObservedObject private var converter = VideoConverter() // Handles video conversion logic

    // MARK: - View Body - Defines the user interface of ContentView

    var body: some View {
        VStack(spacing: 20) { // Main vertical layout with spacing between elements
            // MARK: Drag and Drop Area - UI for dropping video files
            ZStack { // Layers background and text for drag and drop area
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDragging ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDragging ? Color.blue : Color.gray, lineWidth: 2))

                if let videoURL = videoURL {
                    Text("Selected File: \(videoURL.lastPathComponent)") // Display selected filename
                } else {
                    Text("Drag and drop a video file here") // Display drag hint text
                        .foregroundColor(.gray)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in // Handle file drops, update isDragging state
                FileUtilities.handleDrop(providers: providers) { url in // Use FileUtilities to handle dropped files
                    DispatchQueue.main.async { // Update UI on main thread
                        if let url = url, FileUtilities.isVideoFile(url) { // Check if dropped file is a video
                           self.videoURL = url                  // Set video URL if valid
                           self.converter.errorMessage = nil   // Clear error message on new file selection
                           self.successMessage = nil           // Clear success message on new file selection
                       } else {
                           self.converter.errorMessage = "Invalid file type or failed to load." // Set error for invalid file
                       }
                    }
                }
                return true // Indicate drop handling success
            }
            .padding() // Padding around Drag and Drop Area

            // MARK: - Messages Display Area - Displays conversion messages (Error, Success)
            VStack (alignment: .leading) { // VStack to align messages to the left
                if let errorMessage = errorMessage { // Conditionally display error message
                    Text(errorMessage)
                        .foregroundColor(.red)    // Red color for error messages
                        .padding(.horizontal)   // Horizontal padding
                }
                if let successMessage = successMessage { // Conditionally display success message
                    Text(successMessage)
                        .foregroundColor(.green)  // Green color for success messages
                        .padding(.horizontal)   // Horizontal padding
                }
            }

            // MARK: - File Selection Buttons (Horizontal Layout) - "Select File" and "Clear" buttons in HStack
            HStack { // Horizontal button layout
                Button(action: { // "Select File" Button Action: Open file selection dialog
                    FileUtilities.selectFile { url in // Use FileUtilities to show file open panel
                        DispatchQueue.main.async { // Update UI on main thread
                            self.videoURL = url // Set video URL from selected file
                            self.converter.errorMessage = nil // Clear error message on file selection
                            self.successMessage = nil // Clear success message on file selection
                        }
                    }
                }) {
                    Text("Select File")
                        .padding().frame(maxWidth: .infinity).background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
                .padding(.trailing, 5) // Spacing between buttons

                if videoURL != nil { // Conditionally show "Clear" button if video is selected
                    Button(action: { // "Clear" Button Action: Clear video selection and messages
                        videoURL = nil // Reset video URL
                        converter.errorMessage = nil // Clear error message
                    }) {
                        Text("Clear")
                            .padding().background(Color.red).foregroundColor(.white).cornerRadius(10)
                    }
                    .padding(.leading, 5) // Spacing between buttons
                }
            }
            .padding(.horizontal) // Horizontal padding for button row

            // MARK: - Settings and Convert Buttons (Horizontal Layout)
            HStack { // HStack for horizontal layout of buttons
                Button(action: { showSettings = true }) { // Show settings sheet action
                    Text("Settings") // Button text
                        .padding()
                        .frame(maxWidth: .infinity) // Each button takes full width
                        .background(Color.orange) // Orange background color for Button
                        .foregroundColor(.white) // White text color for Button
                        .cornerRadius(10) // Rounded corners for Button
                }
                .padding(.trailing, 5) // Spacing between buttons


                Button(action: { // "Convert Video" Button Action: Start video conversion
                    errorMessage = nil // Clear error message at start of conversion
                    successMessage = nil // Clear success message at start of conversion

                    if let videoURL = videoURL, // Check if a video URL is selected
                       let outputURL = FileUtilities.chooseOutputURL(defaultURL: videoURL.deletingPathExtension().appendingPathExtension(outputFormat)) { // Get output URL using FileUtilities
                        converter.convertVideo( // Call the convertVideo function in VideoConverter to start conversion
                            inputURL: videoURL,
                            outputURL: outputURL,
                            outputFormat: outputFormat,
                            videoCodec: videoCodec,
                            videoQuality: videoQuality,
                            audioCodec: audioCodec
                        )
                    } else {
                        errorMessage = "Please select a valid input video and output location." // Set error message if input or output is invalid
                    }
                }) {
                    if converter.isConverting { // Show progress view if conversion is in progress
                        ProgressView(value: converter.progress) // ProgressView to indicate conversion progress
                            .progressViewStyle(CircularProgressViewStyle()).foregroundColor(.white) // Circular progress style and white color
                    } else {
                        Text("Convert") // "Convert" button text
                            .foregroundColor(.white) // White text color for Button
                    }
                }
                .padding() // Button padding
                .frame(maxWidth: .infinity) // Button takes full width
                .background(Color.green) // Green background color for Button
                .cornerRadius(10) // Rounded corners for Button
                .disabled(videoURL == nil || converter.isConverting) // Disable button if no video selected or during conversion
                .padding(.leading, 5) // Add leading padding to "Convert" button
            } // End of HStack (Settings and Conversion Buttons)
            .padding(.horizontal) // Horizontal padding for the button row
            .sheet(isPresented: $showSettings) { // Present the SettingsView as a sheet
                SettingsView(outputFormat: $outputFormat, videoQuality: $videoQuality, audioCodec: $audioCodec, videoCodec: $videoCodec) // Instantiate SettingsView with bindings
            }
            
            
            // MARK: Cancel Button - Button to cancel ongoing conversion (Shown below other buttons)
            if converter.isConverting { // Conditionally show "Cancel Conversion" button during conversion
                Button(action: { // "Cancel Conversion" Button Action: Cancel video conversion
                    converter.cancelConversion()
                }) {
                    Text("Cancel Conversion")
                        .padding().frame(maxWidth: .infinity).background(Color.red).foregroundColor(.white).cornerRadius(10)
                }
                .padding(.horizontal) // Horizontal padding for Cancel button
            }

        } // End of Main VStack
        .padding() // Padding for the entire ContentView
    } // End of body
} // End of ContentView struct
