import SwiftUI

/// A view for displaying and modifying video conversion settings.
///
/// This view uses bindings to directly modify the settings stored in the `VideoConverter` ViewModel.
/// It is typically presented as a sheet.
struct SettingsView: View {
    // MARK: - Bindings to ViewModel Settings State (Using Enums)

    /// Binding to the selected output format.
    @Binding var outputFormat: OutputFormat

    /// Binding to the selected video quality.
    @Binding var videoQuality: VideoQuality

    /// Binding to the selected audio codec.
    @Binding var audioCodec: AudioCodec

    /// Binding to the selected video codec.
    @Binding var videoCodec: VideoCodec

    // MARK: - Environment

    /// Environment variable to dismiss the sheet.
    @Environment(\.dismiss) var dismiss

    // MARK: - View Body

    var body: some View {
        VStack(spacing: 0) { // Use 0 spacing for tighter control, add padding where needed
            Text("Conversion Settings")
                .font(.title2)
                .padding(.top)
                .padding(.bottom, 10) // Add some space below title

            Form {
                Picker("Output Format", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Picker("Video Codec", selection: $videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }

                Picker("Video Quality", selection: $videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }

                Picker("Audio Codec", selection: $audioCodec) {
                    ForEach(AudioCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
            }
            .formStyle(.grouped) // Gives standardmacOS form styling in a sheet
            .padding(.horizontal) // Padding for the form itself

            // MARK: - Action Button (Done)
            Button("Done") {
                dismiss() // Dismiss the sheet; bindings have already updated the ViewModel
            }
            .keyboardShortcut(.defaultAction) // Allows pressing Enter to dismiss
            .padding() // Make button tap area larger
            .frame(maxWidth: 200) // Limit button width
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.vertical) // Space around the button

        } // End of VStack
        // Suggest ideal size, but allow flexibility
        .frame(minWidth: 320, idealWidth: 380, maxWidth: 500,
               minHeight: 330, idealHeight: 380, maxHeight: 600)
        // Add padding to the whole container if needed, but formStyle might handle it
        // .padding()
    }
}

// MARK: - Preview Provider

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            outputFormat: .constant(.mp4),
            videoQuality: .constant(.medium),
            audioCodec: .constant(.aac),
            videoCodec: .constant(.h264)
        )
        .frame(width: 380, height: 380) // For preview canvas sizing
    }
}
