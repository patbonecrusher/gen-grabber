import SwiftUI

@main
struct GenGrabberApp: App {
    var body: some Scene {
        // A single window, not a WindowGroup: the app works on one folder/session at a time,
        // so opening a folder from Finder should reuse this window and bring it to front rather
        // than spawn a new one.
        Window("Gen Grabber", id: "main") {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
    }
}
