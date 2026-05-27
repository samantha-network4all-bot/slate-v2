import AppKit

class TitleBarView: NSView {

    var onDoubleClick: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Untitled - Notepad")
    private let closeButton = TitleBarButton(role: .close)
    private let maximizeButton = TitleBarButton(role: .maximize)
    private let minimizeButton = TitleBarButton(role: .minimize)

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        wantsLayer = true

        titleLabel.font = Fonts.chrome
        titleLabel.textColor = Colors.chromeText
        titleLabel.lineBreakMode = .byTruncatingTail

        addSubview(titleLabel)
        addSubview(closeButton)
        addSubview(maximizeButton)
        addSubview(minimizeButton)

        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        maximizeButton.target = self
        maximizeButton.action = #selector(maximizeClicked)
        minimizeButton.target = self
        minimizeButton.action = #selector(minimizeClicked)
    }

    override func layout() {
        super.layout()

        let w = bounds.width
        let h = bounds.height
        let bw = Metrics.titleBarButtonWidth

        minimizeButton.frame = CGRect(x: w - 3 * bw, y: 0, width: bw, height: h)
        maximizeButton.frame = CGRect(x: w - 2 * bw, y: 0, width: bw, height: h)
        closeButton.frame   = CGRect(x: w - 1 * bw, y: 0, width: bw, height: h)

        titleLabel.frame = CGRect(x: Metrics.titleBarPaddingLeft, y: 0, width: max(0, w - 3 * bw - Metrics.titleBarPaddingLeft - 8), height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Colors.chromeBackground.setFill()
        dirtyRect.fill()

        // Bottom separator
        let sep = CGRect(x: 0, y: 0, width: bounds.width, height: 1)
        Colors.chromeBorder.setFill()
        sep.fill()
    }

    func updateTitle(_ title: String) {
        titleLabel.stringValue = title
    }

    override func mouseDragged(with event: NSEvent) {
        if let window = self.window {
            window.performDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        }
    }

    @objc private func closeClicked() {
        window?.close()
    }

    @objc private func minimizeClicked() {
        window?.miniaturize(nil)
    }

    @objc private func maximizeClicked() {
        window?.zoom(nil)
    }
}
