import SwiftUI

struct SettingsView: View {
    @Binding var outputFormat: OutputFormat
    @Binding var videoQuality: VideoQuality
    @Binding var audioCodec: AudioCodec
    @Binding var videoCodec: VideoCodec
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Conversion Settings")
                .font(.headline)
                .padding(.top)

            Form {
                Section(header: Text("Video")) {
                    Picker("Format", selection: $outputFormat) {
                        ForEach(OutputFormat.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Codec", selection: $videoCodec) {
                        ForEach(VideoCodec.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Quality", selection: $videoQuality) {
                        ForEach(VideoQuality.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                
                Section(header: Text("Audio")) {
                    Picker("Codec", selection: $audioCodec) {
                        ForEach(AudioCodec.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .formStyle(.grouped)

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 350, height: 400)
    }
}
