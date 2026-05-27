import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the initial untitled window
        let controller = SlateWindowController(untitled: true)
        controller.showWindow(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the test API listener so no new connections are accepted.
        TestAPIServer.shared.stop()
        // Remove the port file so the harness detects the process has exited.
        try? FileManager.default.removeItem(atPath: testAPIPortFilePath)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        return true
    }
}
