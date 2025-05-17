import SwiftUI

struct ContentView: View {
    @StateObject private var converter = VideoConverter()
    @State private var isDragging = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 15) {
            // MARK: - Settings and Global Messages
            HStack {
                Text("Batch Video Converter")
                    .font(.title2)
                Spacer()
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open conversion settings (applied to all files in batch)")
            }
            .padding(.horizontal)

            if let globalError = converter.globalErrorMessage {
                Text(globalError)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // MARK: - File Queue List
            if converter.fileQueue.isEmpty {
                DropAreaView(isDragging: $isDragging, onDrop: handleDrop)
                    .frame(height: 150)
                    .padding(.horizontal)
                Text("Drag & drop video files or folders here, or use 'Add Files'.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                List {
                    ForEach(converter.fileQueue) { item in // Use $ for bindings if needed for inline edits
                        FileQueueRow(item: item)
                    }
                    .onDelete(perform: converter.removeItemFromQueue)
                }
                .frame(minHeight: 200, idealHeight: 300) // Give some space for the list
                 DropAreaView(isDragging: $isDragging, onDrop: handleDrop) // Smaller drop area below list
                    .frame(height: 50)
                    .padding(.horizontal)

            }


            // MARK: - Action Buttons
            HStack {
                Button {
                    FileUtilities.selectFiles { urls in
                        if let urls = urls {
                            converter.addFilesToQueue(urls: urls)
                        }
                    }
                } label: {
                    Label("Add Files", systemImage: "plus.circle.fill")
                        .padding(.horizontal)
                }
                .disabled(converter.isBatchConverting)


                if !converter.fileQueue.isEmpty {
                    Button {
                        converter.clearQueue()
                    } label: {
                        Label("Clear Queue", systemImage: "trash")
                            .padding(.horizontal)
                    }
                    .disabled(converter.isBatchConverting)
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal)


            Text(converter.overallProgressMessage)
                .font(.caption)
                .frame(height: 20) // Ensure space for this message
                .padding(.horizontal)


            // MARK: - Convert / Cancel Batch Button
            if !converter.fileQueue.isEmpty {
                if converter.isBatchConverting {
                    Button {
                        converter.cancelBatchConversion()
                    } label: {
                        Label("Cancel Batch", systemImage: "xmark.octagon.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    Button {
                        converter.selectOutputDirectoryAndStartBatch()
                    } label: {
                        Label("Convert All (\(converter.fileQueue.count))", systemImage: "film.stack")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(converter.fileQueue.filter({ $0.status == .pending || $0.status == .failed || $0.status == .cancelled }).isEmpty) // Disable if all are completed/skipped
                }
            }


            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSettings) {
            SettingsView(
                outputFormat: $converter.outputFormat,
                videoQuality: $converter.videoQuality,
                audioCodec: $converter.audioCodec,
                videoCodec: $converter.videoCodec
            )
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        FileUtilities.handleDrop(providers: providers) { urls in
            if let urls = urls, !urls.isEmpty {
                converter.addFilesToQueue(urls: urls)
            }
        }
    }
}

// MARK: - Helper Drop Area View
struct DropAreaView: View {
    @Binding var isDragging: Bool
    var onDrop: ([NSItemProvider]) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isDragging ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isDragging ? Color.blue : Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            if !isDragging { // Only show text if not actively dragging over
                 Text("Drop Files/Folders Here")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            onDrop(providers)
            return true
        }
    }
}


// MARK: - File Queue Row View
struct FileQueueRow: View {
    let item: FileQueueItem // item is a struct, passed directly

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { // Added spacing
                Text(item.inputURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Display progress bar and percentage if converting
                if item.status == .converting {
                    HStack {
                        ProgressView(value: item.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text(String(format: "%.0f%%", item.progress * 100))
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing) // Give fixed width for percentage
                    }
                } else if item.status == .completed {
                    // Display success message which now includes compression info
                    if let successMsg = item.successMessage {
                        // Split the success message for better layout if needed
                        // For now, display as is, it might wrap.
                        // Example: "Completed: file.mp4\nOriginal: 10 MB, New: 5MB. Reduced by 50%."
                        Text(successMsg.replacingOccurrences(of: "\n", with: " ")) // Replace newline with space for single line
                            .font(.caption)
                            .foregroundColor(statusColor(item.status))
                            .lineLimit(2) // Allow two lines for this info
                            .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                    } else {
                        Text("Status: \(item.status.displayName)")
                            .font(.caption)
                            .foregroundColor(statusColor(item.status))
                    }
                } else {
                    // Display regular status for other states
                    Text("Status: \(item.status.displayName)")
                        .font(.caption)
                        .foregroundColor(statusColor(item.status))
                }

                if let errorMessage = item.errorMessage, item.status == .failed || item.status == .cancelled {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            Spacer() // Pushes the status icon to the right

            // Status Icon
            statusIcon(for: item.status)
        }
        .padding(.vertical, 6) // Increased padding for better spacing
    }

    // Helper for status icon
    @ViewBuilder
    private func statusIcon(for status: ConversionStatus) -> some View {
        switch status {
        case .converting:
            ProgressView().scaleEffect(0.7) // Spinner
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed, .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .pending, .preparing, .skipped:
            EmptyView() // No icon for these, or add one if desired
        }
    }

    private func statusColor(_ status: ConversionStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .preparing: return .orange
        case .converting: return .blue // Or use default text color
        case .completed: return .green
        case .failed, .cancelled: return .red
        case .skipped: return .purple
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
