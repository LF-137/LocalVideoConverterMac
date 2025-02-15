import SwiftUI

/// SwiftUI View for displaying and modifying video conversion settings.
///
/// This view presents a form with pickers to adjust output format, video/audio codecs, and video quality.
/// It is presented as a sheet from ContentView.
struct SettingsView: View {
    // MARK: - Bindings to Settings State in ContentView

    /// Binding to the selected output format (`.mp4`, `.mov`, etc.).
    @Binding var outputFormat: String

    /// Binding to the selected video quality (`"high"`, `"medium"`, `"low"`).
    /// This is used to determine the CRF value for quality-based encoding.
    @Binding var videoQuality: String

    /// Binding to the selected audio codec (`"aac"`, `"mp3"`, `"none"`).
    @Binding var audioCodec: String

    /// Binding to the selected video codec (`"h264"`, `"hevc"`).
    @Binding var videoCodec: String

    /// Environment variable to control the presentation mode of the sheet.
    /// Used to dismiss (close) the SettingsView.
    @Environment(\.presentationMode) var presentationMode


    // MARK: - View Body

    var body: some View {
        VStack { // Main vertical layout for SettingsView
            Form { // SwiftUI Form for grouping settings pickers
                // MARK: - Output Format Picker
                Picker("Output Format", selection: $outputFormat) { // Picker for output format setting
                    Text("MP4").tag("mp4") // Option for MP4 format
                    Text("MOV").tag("mov") // Option for MOV format
                    // Add more format options here if needed (e.g., "AVI", "MKV")
                }


                // MARK: - Video Codec Picker
                Picker("Video Codec", selection: $videoCodec) { // Picker for video codec setting
                    Text("H.264").tag("h264") // Option for H.264 codec
                    Text("HEVC (H.265)").tag("hevc") // Option for HEVC (H.265) codec
                }


                // MARK: - Video Quality Picker
                Picker("Video Quality", selection: $videoQuality) { // Picker for video quality setting
                    Text("High").tag("high") // Option for High quality
                    Text("Medium").tag("medium") // Option for Medium quality
                    Text("Low").tag("low") // Option for Low quality
                }


                // MARK: - Audio Codec Picker
                Picker("Audio Codec", selection: $audioCodec) { // Picker for audio codec setting
                    Text("AAC").tag("aac") // Option for AAC audio codec
                    Text("MP3").tag("mp3") // Option for MP3 audio codec
                    Text("None").tag("none") // Option to disable audio ("none")
                }
            } // End of Form
            .padding()


            // MARK: - Action Buttons (Cancel and Save)
            HStack { // Horizontal layout for Cancel and Save buttons
                Button(action: { // Cancel button action
                    presentationMode.wrappedValue.dismiss() // Dismiss the SettingsView sheet (close settings without saving)
                }) {
                    Text("Cancel") // Cancel button text
                        .padding()
                        .frame(maxWidth: .infinity) // Button takes full width
                        .background(Color.red) // Red background color for Cancel button
                        .foregroundColor(.white) // White text color for Cancel button
                        .cornerRadius(10) // Rounded corners for Cancel button
                }

                Button(action: { // Save button action
                    presentationMode.wrappedValue.dismiss() // Dismiss the SettingsView sheet (close settings and save - settings are bound, so they are already updated)
                }) {
                    Text("Save") // Save button text
                        .padding()
                        .frame(maxWidth: .infinity) // Button takes full width
                        .background(Color.blue) // Blue background color for Save button
                        .foregroundColor(.white) // White text color for Save button
                        .cornerRadius(10) // Rounded corners for Save button
                }
            } // End of HStack (Action Buttons)
            .padding() // Add padding to the HStack of buttons

        } // End of VStack (Main Layout)
        .frame(width: 300, height: 300) // Set a fixed size for the SettingsView sheet
    } // End of body
} // End of SettingsView struct


// MARK: - Preview Provider (for Xcode Canvas)

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView( // Create SettingsView for preview
            outputFormat: .constant("mp4"), // Provide constant binding for outputFormat (default "mp4")
            videoQuality: .constant("high"), // Provide constant binding for videoQuality (default "high")
            audioCodec: .constant("aac"),   // Provide constant binding for audioCodec (default "aac")
            videoCodec: .constant("h264")    // Provide constant binding for videoCodec (default "h264")
        )
    }
}
