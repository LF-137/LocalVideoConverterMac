import SwiftUI
import AppKit // Import AppKit for NSApplication functionalities

/// Main application struct for the LocalVideoConverterMac app.
///
/// This struct conforms to the `App` protocol and defines the app's lifecycle and main window.
@main
struct LocalVideoConverterMacApp: App {

    // MARK: - App Body

    /// Defines the content and behavior of the app's main window.
    var body: some Scene {
        WindowGroup { // Creates a window that can display SwiftUI views
            ContentView() // Set ContentView as the main content of the window
                .onAppear { // Code to execute when the ContentView appears (window is shown)
                    // Ensure the app quits completely when the last window is closed.
                    // By default, macOS apps may remain active in the background even after windows are closed.
                    NSApplication.shared.windows.first?.isReleasedWhenClosed = false
                    // Setting `isReleasedWhenClosed = false` on the first window prevents the app from quitting
                    // when the window is initially closed. This is then handled in `onDisappear` for the last window.
                }
                .onDisappear { // Code to execute when the ContentView disappears (window is closed)
                    // Check if all app windows are closed
                    if NSApplication.shared.windows.isEmpty {
                        // Terminate the application if no windows are open.
                        // This ensures the app quits fully when the user closes the last window.
                        NSApplication.shared.terminate(nil)
                    }
                }
        } // End of WindowGroup
    } // End of body
} // End of LocalVideoConverterMacApp struct
