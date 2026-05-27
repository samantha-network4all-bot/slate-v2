import AppKit

enum TitleBarButtonRole {
    case minimize
    case maximize
    case close
}

class TitleBarButton: NSButton {

    private let role: TitleBarButtonRole
    private var isHovered = false

    init(role: TitleBarButtonRole) {
        self.role = role
        super.init(frame: .zero)
        self.isBordered = false
        self.title = ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if role == .close {
            if isHovered {
                Colors.closeButtonHover.setFill()
                bounds.fill()
            }
        } else {
            if isHovered {
                Colors.titleBarButtonHover.setFill()
                bounds.fill()
            }
        }

        let iconColor: NSColor
        if role == .close && isHovered {
            iconColor = .white
        } else {
            iconColor = Colors.chromeText
        }

        let size = Metrics.titleBarIconSize
        let cx = bounds.midX
        let cy = bounds.midY

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.setStrokeColor(iconColor.cgColor)
        ctx.setLineWidth(1)
        ctx.setLineCap(.round)

        switch role {
        case .minimize:
            ctx.move(to: CGPoint(x: cx - size / 2, y: cy))
            ctx.addLine(to: CGPoint(x: cx + size / 2, y: cy))
            ctx.strokePath()

        case .maximize:
            let r = CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
            ctx.stroke(r)

        case .close:
            ctx.move(to: CGPoint(x: cx - size / 2, y: cy - size / 2))
            ctx.addLine(to: CGPoint(x: cx + size / 2, y: cy + size / 2))
            ctx.move(to: CGPoint(x: cx + size / 2, y: cy - size / 2))
            ctx.addLine(to: CGPoint(x: cx - size / 2, y: cy + size / 2))
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}
