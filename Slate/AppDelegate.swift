import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appController: AppController?

    func applicationDidFinishLaunching(_ n: Notification) {
        appController = AppController()
        appController?.launch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
