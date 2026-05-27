import AppKit

class DocumentController {

    static let shared = DocumentController()

    private(set) var windowControllers: [SlateWindowController] = []

    private init() {}

    func addWindowController(_ controller: SlateWindowController) {
        windowControllers.append(controller)
    }

    func removeWindowController(_ controller: SlateWindowController) {
        if let index = windowControllers.firstIndex(where: { $0 === controller }) {
            windowControllers.remove(at: index)
        }
    }

    func windowController(for window: NSWindow) -> SlateWindowController? {
        return windowControllers.first { $0.window === window }
    }
}

extension Notification.Name {
    static let slateNewDocument = Notification.Name("slate-new-document")
}
