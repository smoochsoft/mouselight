import SwiftUI

@main
struct MouseLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Use WindowGroup with zero-size invisible window since we manage our own windows
        // This is a menu bar app - all UI is managed via AppDelegate
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
    }
}
