import SwiftUI

struct SettingsView: View {
    @Binding var outputFormat: String
    @Binding var videoQuality: String
    @Binding var audioCodec: String
    @Environment(\.presentationMode) var presentationMode // To dismiss the sheet

    var body: some View {
        VStack {
            // Settings Form
            Form {
                Picker("Output Format", selection: $outputFormat) {
                    Text("MP4").tag("mp4")
                    Text("MOV").tag("mov")
                    Text("AVI").tag("avi")
                    Text("MKV").tag("mkv")
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

            // Save and Cancel Buttons
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss() // Dismiss the sheet
                }) {
                    Text("Cancel")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    // Save settings (no additional action needed since @Binding updates automatically)
                    presentationMode.wrappedValue.dismiss() // Dismiss the sheet
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
        .frame(width: 300, height: 300)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            outputFormat: .constant("mp4"),
            videoQuality: .constant("high"),
            audioCodec: .constant("aac")
        )
    }
}
