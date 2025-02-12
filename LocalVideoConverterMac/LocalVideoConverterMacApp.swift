import SwiftUI
import AppKit // Required for NSApplication

@main
struct LocalVideoConverterMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Ensure the app quits when the last window is closed
                    NSApplication.shared.windows.first?.isReleasedWhenClosed = false
                }
                .onDisappear {
                    if NSApplication.shared.windows.isEmpty {
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
    }
}
