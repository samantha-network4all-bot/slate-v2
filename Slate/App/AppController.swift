import Foundation
import AppKit

final class AppController: NSObject {
    var windowController: SlateWindowController?

    func launch() {
        let wc = SlateWindowController()
        windowController = wc
        wc.showWindow(nil)

        if ProcessInfo.processInfo.environment["SLATE_TEST_API"] == "1" {
            registerTestAPIRoutes()
            TestAPIServer.shared.start()
        }
    }

    private func registerTestAPIRoutes() {
        let router = TestAPIRouter.shared

        router.get(path: "/healthz") { _ in
            .ok(json: Data(#"{"ok":true}"#.utf8))
        }

        router.post(path: "/app/shutdown") { _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return .ok(json: Data(#"{"ok":true}"#.utf8))
        }
    }
}
