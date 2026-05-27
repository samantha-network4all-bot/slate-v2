import AppKit

class SlateWindow: NSWindow {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init() {
        let contentRect = NSRect(origin: .zero, size: Metrics.defaultWindowSize)
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = true
        self.backgroundColor = Colors.chromeBackground
        self.hasShadow = true
        self.title = "Untitled - Notepad"
        self.titleVisibility = .visible

        // Position: top-right against screen visibleFrame
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let x = vf.maxX - Metrics.defaultWindowSize.width
            let y = vf.maxY - Metrics.defaultWindowSize.height
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
