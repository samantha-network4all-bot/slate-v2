import AppKit

final class SlateWindow: NSWindow {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.defaultWindowSize.width, height: Metrics.defaultWindowSize.height),
            styleMask: [.borderless, .resizable, .miniaturizable, .closable],
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = false
        self.backgroundColor = Colors.chromeBackground

        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.white.cgColor
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
