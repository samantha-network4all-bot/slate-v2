import AppKit

final class TitleBarView: NSView {

    private let titleLabel: NSTextField
    private var isHoveringClose = false
    private var isHoveringMin = false
    private var isHoveringMax = false

    init() {
        titleLabel = NSTextField(labelWithString: "Untitled - Notepad")
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Metrics.titleBarHeight))
        titleLabel.font = Fonts.chrome
        titleLabel.textColor = Colors.chromeText
        titleLabel.sizeToFit()
        addSubview(titleLabel)

        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: Metrics.titleBarHeight)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        titleLabel.frame = NSRect(
            x: Metrics.titleBarPaddingLeft,
            y: (Metrics.titleBarHeight - titleLabel.intrinsicContentSize.height) / 2,
            width: titleLabel.intrinsicContentSize.width,
            height: titleLabel.intrinsicContentSize.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bottomLine = NSRect(x: 0, y: 0, width: bounds.width, height: 1)
        Colors.chromeBorder.setFill()
        bottomLine.fill()

        let buttonY = (Metrics.titleBarHeight - Metrics.titleBarButtonHeight) / 2
        let buttonWidth = Metrics.titleBarButtonWidth
        let totalButtonsWidth = buttonWidth * 3
        var x = bounds.width - totalButtonsWidth

        // Minimize button (placeholder)
        let minRect = NSRect(x: x, y: buttonY, width: buttonWidth, height: Metrics.titleBarButtonHeight)
        if isHoveringMin {
            Colors.titleBarButtonHover.setFill()
            minRect.fill()
        }
        x += buttonWidth

        // Maximize button (placeholder)
        let maxRect = NSRect(x: x, y: buttonY, width: buttonWidth, height: Metrics.titleBarButtonHeight)
        if isHoveringMax {
            Colors.titleBarButtonHover.setFill()
            maxRect.fill()
        }
        x += buttonWidth

        // Close button (placeholder)
        let closeRect = NSRect(x: x, y: buttonY, width: buttonWidth, height: Metrics.titleBarButtonHeight)
        if isHoveringClose {
            Colors.closeButtonHover.setFill()
            closeRect.fill()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentOrigin = window.frame.origin
        let newOrigin = NSPoint(
            x: currentOrigin.x + event.deltaX,
            y: currentOrigin.y - event.deltaY
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let buttonWidth = Metrics.titleBarButtonWidth
        let totalButtonsWidth = buttonWidth * 3
        let buttonStartX = bounds.width - totalButtonsWidth

        if location.x < buttonStartX && event.clickCount == 2 {
            window?.zoom(nil)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        // Hover tracking would go here with proper tracking areas
    }

    override func mouseExited(with event: NSEvent) {
        // Hover tracking would go here
    }
}
