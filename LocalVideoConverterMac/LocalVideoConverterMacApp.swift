import SwiftUI

@main
struct LocalVideoConverterMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle()) // Optional: Hide the title bar for a cleaner look
    }
}
