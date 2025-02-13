import SwiftUI

struct SettingsView: View {
    @Binding var outputFormat: String
    @Binding var videoQuality: String
    @Binding var audioCodec: String
    @Binding var videoCodec: String  // NEW: Add binding for the video codec
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Form {
                Picker("Output Format", selection: $outputFormat) {
                    Text("MP4").tag("mp4")
                    Text("MOV").tag("mov")
                    // ... other formats
                }

                // NEW: Video Codec Picker
                Picker("Video Codec", selection: $videoCodec) {
                    Text("H.264").tag("h264")
                    Text("HEVC (H.265)").tag("hevc")
                }

                Picker("Video Quality", selection: $videoQuality) {
                    Text("High").tag("high")
                    Text("Medium").tag("medium")
                    Text("Low").tag("low")
                }

                Picker("Audio Codec", selection: $audioCodec) {
                    Text("AAC").tag("aac")
                    Text("MP3").tag("mp3")
                    Text("None").tag("none")
                }
            }
            .padding()

            HStack { //Cancel and Save Buttons
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Save")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .frame(width: 300, height: 300) //Adjust Size for the new Picker
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            outputFormat: .constant("mp4"),
            videoQuality: .constant("high"),
            audioCodec: .constant("aac"),
            videoCodec: .constant("h264") // Provide a default value for the preview
        )
    }
}
