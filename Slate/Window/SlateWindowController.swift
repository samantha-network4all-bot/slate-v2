import AppKit

final class SlateWindowController: NSWindowController {

    private let titleBar = TitleBarView()

    init() {
        let window = SlateWindow()
        super.init(window: window)
        setupWindow(window)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupWindow(_ window: SlateWindow) {
        guard let contentView = window.contentView else { return }

        titleBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleBar)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: Metrics.titleBarHeight)
        ])

        positionWindowTopRight(window)
    }

    private func positionWindowTopRight(_ window: NSWindow) {
        let screen = NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 600, width: Metrics.defaultWindowSize.width, height: Metrics.defaultWindowSize.height)

        let x = visibleFrame.maxX - Metrics.defaultWindowSize.width
        let y = visibleFrame.maxY - Metrics.defaultWindowSize.height
        window.setFrame(NSRect(x: x, y: y, width: Metrics.defaultWindowSize.width, height: Metrics.defaultWindowSize.height), display: true)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        registerTestAPIRoutes()
    }

    private func registerTestAPIRoutes() {
        TestAPIRouter.shared.get(prefix: "window", path: "/list") { [weak self] _ in
            guard let self, let window = self.window else {
                return .ok(json: Data("[]".utf8))
            }
            let title = window.title
            let isKey = window.isKeyWindow
            let json = #"[{"title":"\#(title)","isKey":\#(isKey)}]}"#
            return .ok(json: Data(json.utf8))
        }

        TestAPIRouter.shared.get(prefix: "window", path: "/screenshot") { [weak self] _ in
            guard let self, let window = self.window,
                  let view = window.contentView else {
                return .notFound()
            }
            DispatchQueue.main.sync {
                // no-op, already on main
            }
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                return .badRequest("bitmap create failed")
            }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                return .badRequest("png encode failed")
            }
            return TestAPIResponse(status: 200, headers: ["Content-Type": "image/png"], body: pngData)
        }
    }
}
