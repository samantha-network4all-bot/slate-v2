import AppKit

class SlateWindowController: NSWindowController {

    private var titleBar: TitleBarView!
    private var statusBar: StatusBarView!
    private var editorView: EditorView!
    private var editorScrollView: NSScrollView!

    var editor: EditorView { return editorView }

    init(untitled: Bool = true) {
        let window = SlateWindow()
        super.init(window: window)

        setupContent()
        DocumentController.shared.addWindowController(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        updateTitle("Untitled - Notepad")
    }

    private func setupContent() {
        guard let win = window else { return }
        let contentView = win.contentView!

        let sb = Metrics.statusBarHeight
        let tb = Metrics.titleBarHeight

        // Title bar
        titleBar = TitleBarView(frame: CGRect(x: 0, y: contentView.bounds.height - tb, width: contentView.bounds.width, height: tb))
        titleBar.autoresizingMask = [.width, .minYMargin]
        titleBar.onDoubleClick = { [weak self] in
            self?.window?.zoom(nil)
        }
        contentView.addSubview(titleBar)

        // Status bar
        statusBar = StatusBarView(frame: CGRect(x: 0, y: 0, width: contentView.bounds.width, height: sb))
        statusBar.autoresizingMask = [.width, .maxYMargin]
        contentView.addSubview(statusBar)

        // Editor: canonical construction via storage chain (done in EditorView.init)
        editorView = EditorView()
        editorScrollView = NSScrollView(frame: CGRect(x: 0, y: sb, width: contentView.bounds.width, height: contentView.bounds.height - tb - sb))
        editorScrollView.autoresizingMask = [.width, .height]
        editorScrollView.hasVerticalScroller = true
        editorScrollView.hasHorizontalScroller = true
        editorScrollView.documentView = editorView
        editorScrollView.scrollerStyle = .legacy
        editorScrollView.drawsBackground = false
        editorView.minSize = NSSize(width: 0, height: editorScrollView.contentSize.height)
        editorView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editorView.isVerticallyResizable = true
        editorView.isHorizontallyResizable = false
        editorView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editorView.textContainer?.widthTracksTextView = true
        contentView.addSubview(editorScrollView)
    }

    private func updateTitle(_ title: String) {
        titleBar?.updateTitle(title)
        window?.title = title
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let win = window else { return }
        win.makeFirstResponder(editorView)
    }

    deinit {
        DocumentController.shared.removeWindowController(self)
    }
}
