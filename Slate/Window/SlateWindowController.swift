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
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

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
            var result = Data()
            DispatchQueue.main.sync {
                let title = "Untitled - Notepad"
                let isKey = window.isKeyWindow
                let obj = [["title": title, "isKey": isKey]]
                result = try! JSONSerialization.data(withJSONObject: obj)
            }
            return .ok(json: result)
        }

        TestAPIRouter.shared.get(prefix: "window", path: "/screenshot") { [weak self] _ in
            guard let self, let window = self.window,
                  let view = window.contentView else {
                return .notFound()
            }
            var pngData: Data?
            DispatchQueue.main.sync {
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                pngData = rep.representation(using: .png, properties: [:])
            }
            guard let data = pngData else {
                return .badRequest("screenshot failed")
            }
            return TestAPIResponse(status: 200, headers: ["Content-Type": "image/png"], body: data)
        }
    }
}
