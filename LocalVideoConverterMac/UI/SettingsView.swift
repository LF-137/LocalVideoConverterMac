import SwiftUI

/// A view for displaying and modifying video conversion settings.
///
/// This view uses bindings to directly modify the settings stored in the `VideoConverter` ViewModel.
/// It is typically presented as a sheet.
struct SettingsView: View {
    // MARK: - Bindings to ViewModel Settings State

    /// Binding to the selected output format (e.g., "mp4", "mov").
    @Binding var outputFormat: String

    /// Binding to the selected video quality ("high", "medium", "low").
    @Binding var videoQuality: String

    /// Binding to the selected audio codec ("aac", "mp3", "none").
    @Binding var audioCodec: String

    /// Binding to the selected video codec ("h264", "hevc").
    @Binding var videoCodec: String

    // MARK: - Environment

    /// Environment variable to dismiss the sheet.
    @Environment(\.dismiss) var dismiss

    // MARK: - Available Options (Consider moving to ViewModel or a Constants file)

    private let outputFormats = ["mp4", "mov"] // Example formats
    private let videoCodecs = ["h264", "hevc"] // Example video codecs
    private let videoQualities = ["high", "medium", "low"] // Example qualities
    private let audioCodecs = ["aac", "mp3", "none"] // Example audio codecs

    // MARK: - View Body

    var body: some View {
        VStack {
            Text("Conversion Settings").font(.title2).padding(.top)
            Form {
                Picker("Output Format", selection: $outputFormat) {
                    ForEach(outputFormats, id: \.self) { format in
                        Text(format.uppercased()).tag(format)
                    }
                }

                Picker("Video Codec", selection: $videoCodec) {
                    ForEach(videoCodecs, id: \.self) { codec in
                        Text(codec == "hevc" ? "HEVC (H.265)" : "H.264").tag(codec)
                    }
                }

                Picker("Video Quality", selection: $videoQuality) {
                    ForEach(videoQualities, id: \.self) { quality in
                        Text(quality.capitalized).tag(quality)
                    }
                }

                Picker("Audio Codec", selection: $audioCodec) {
                    ForEach(audioCodecs, id: \.self) { codec in
                        Text(codec.uppercased()).tag(codec)
                    }
                }
            }
            .padding()

            // MARK: - Action Button (Done)
            Button("Done") {
                dismiss() // Dismiss the sheet; bindings have already updated the ViewModel
            }
            .keyboardShortcut(.defaultAction) // Allows pressing Enter to dismiss
            .padding()
            .frame(maxWidth: 200)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.bottom)


        } // End of VStack
        .frame(width: 350, height: 350) // Adjust size as needed
    }
}

// MARK: - Preview Provider

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            outputFormat: .constant("mp4"),
            videoQuality: .constant("medium"),
            audioCodec: .constant("aac"),
            videoCodec: .constant("h264")
        )
    }
}
