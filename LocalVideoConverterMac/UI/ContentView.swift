import SwiftUI

struct ContentView: View {
    @StateObject private var converter = VideoConverter()
    // @State private var isDragging = false // No longer needed
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
                // Display a message when the queue is empty, instead of the drop zone
                VStack {
                    Spacer() // Pushes content to center
                    Image(systemName: "doc.on.doc") // Example icon
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    Text("No files in queue.")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("Click 'Add Files' to select videos for conversion.")
                        .font(.callout)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer() // Pushes content to center
                }
                .frame(minHeight: 150, idealHeight: 250) // Give it some space
                .padding(.horizontal)

            } else {
                List {
                    ForEach(converter.fileQueue) { item in
                        FileQueueRow(item: item)
                    }
                    .onDelete(perform: converter.removeItemFromQueue)
                }
                .frame(minHeight: 200, idealHeight: 300)
            }

            // MARK: - Action Buttons
            HStack {
                Button {
                    FileUtilities.selectFiles { urls in
                        if let urls = urls, !urls.isEmpty { // Ensure urls is not nil AND not empty
                            // VideoConverter's addFilesToQueue will handle starting access
                            converter.addFilesToQueue(urls: urls, accessAlreadyStarted: true)
                            // accessAlreadyStarted: true because FileUtilities.selectFiles now starts access.
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
                .frame(height: 20)
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
                    // Disable if no files are in a state to be converted
                    .disabled(converter.fileQueue.allSatisfy { $0.status == .completed || $0.status == .skipped })
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
        // REMOVED: .onDrop modifier and related DropAreaView if it was solely for drag-and-drop.
        // If DropAreaView had other UI purposes, you might keep its visual structure but remove .onDrop.
        // For simplicity, I've removed the direct DropAreaView call assuming its primary role was dropping.
    }

    // REMOVED: private func handleDrop(providers: [NSItemProvider])
    // as it's no longer used.
}

// If DropAreaView was defined in ContentView.swift and only used for drag-and-drop,
// you can remove its definition as well.
// struct DropAreaView: View { ... } // REMOVE IF ONLY FOR DRAG-DROP

// FileQueueRow remains the same
struct FileQueueRow: View {
    let item: FileQueueItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.inputURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.status == .converting {
                    HStack {
                        ProgressView(value: item.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text(String(format: "%.0f%%", item.progress * 100))
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                    }
                } else if item.status == .completed {
                    if let successMsg = item.successMessage {
                        Text(successMsg.replacingOccurrences(of: "\n", with: " "))
                            .font(.caption)
                            .foregroundColor(statusColor(item.status))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Status: \(item.status.displayName)")
                            .font(.caption)
                            .foregroundColor(statusColor(item.status))
                    }
                } else {
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
            Spacer()
            statusIcon(for: item.status)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func statusIcon(for status: ConversionStatus) -> some View {
        switch status {
        case .converting: ProgressView().scaleEffect(0.7)
        case .completed: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed, .cancelled: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        default: EmptyView()
        }
    }

    private func statusColor(_ status: ConversionStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .preparing: return .orange
        case .converting: return .blue
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
