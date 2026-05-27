import AppKit

class StatusBarView: NSView {

    private let leftLabel = NSTextField(labelWithString: "Ln 1, Col 1")
    private let zoomLabel = NSTextField(labelWithString: "100%")
    private let lineEndingLabel = NSTextField(labelWithString: "Windows (CRLF)")
    private let encodingLabel = NSTextField(labelWithString: "UTF-8")

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
        leftLabel.font = Fonts.statusBar
        leftLabel.textColor = Colors.chromeText

        let rightItems: [NSTextField] = [zoomLabel, lineEndingLabel, encodingLabel]
        rightItems.forEach { item in
            item.font = Fonts.statusBar
            item.textColor = Colors.chromeText
        }

        addSubview(leftLabel)
        addSubview(zoomLabel)
        addSubview(lineEndingLabel)
        addSubview(encodingLabel)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Colors.statusBarBg.setFill()
        dirtyRect.fill()

        // Top separator
        let sep = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        Colors.statusBarSeparator.setFill()
        sep.fill()
    }

    override func layout() {
        super.layout()

        let h = bounds.height
        let pad = Metrics.statusSegmentPaddingH

        // Left label
        leftLabel.sizeToFit()
        leftLabel.frame = CGRect(x: pad, y: 0, width: leftLabel.bounds.width, height: h)

        // Right labels — right to left stacking
        rightLabels().reversed().forEach { $0.sizeToFit() }

        let items = rightLabels()
        var x = bounds.width
        for item in items.reversed() {
            x -= item.bounds.width + pad * 2 + 1
            item.frame = CGRect(x: x + pad, y: 0, width: item.bounds.width, height: h)
        }
    }

    private func rightLabels() -> [NSTextField] {
        [zoomLabel, lineEndingLabel, encodingLabel]
    }
}
