import Foundation
import AppKit

// MARK: - HTTPResponse

struct HTTPResponse {
    let status: Int
    let body: String
    let binaryBody: Data?
    let contentType: String

    init(status: Int, body: String, binaryBody: Data? = nil, contentType: String = "application/json") {
        self.status = status
        self.body = body
        self.binaryBody = binaryBody
        self.contentType = contentType
    }

    var statusText: String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 409: return "Conflict"
        case 500: return "Internal Server Error"
        default:  return "Unknown"
        }
    }

    var eventualBody: String { body }
}

// MARK: - Route handling

struct TestAPIRoutes {

    static func handle(method: String, path: String, body: String?) -> HTTPResponse {
        switch (method, path) {

        case ("GET", "/healthz"):
            return HTTPResponse(status: 200, body: #"{"ok":true}"#)

        case ("GET", "/windows"):
            return windowsResponse()

        case ("GET", "/screenshot"):
            return screenshotResponse()

        default:
            return HTTPResponse(status: 404, body: #"{"error":"not found"}"#)
        }
    }

    private static func screenshotResponse() -> HTTPResponse {
        var pngData: Data?
        DispatchQueue.main.sync {
            guard let controller = DocumentController.shared.windowControllers.first else { return }
            guard let view = controller.window?.contentView else { return }
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            pngData = rep.representation(using: .png, properties: [:])
        }

        if let data = pngData {
            return HTTPResponse(status: 200, body: "", binaryBody: data, contentType: "image/png")
        }
        return HTTPResponse(status: 500, body: #"{"error":"screenshot failed"}"#)
    }

    private static func windowsResponse() -> HTTPResponse {
        // Dispatch to main queue before touching AppKit (§8.12)
        let result = DispatchQueue.main.sync {
            var windows: [[String: Any]] = []
            let controllers = DocumentController.shared.windowControllers
            let count = controllers.count
            for (index, controller) in controllers.enumerated() {
                let title = controller.window?.title ?? "Untitled - Notepad"
                // Single-window sessions: treat the only window as key.
                // In headless/CI environments isKeyWindow may be false even
                // though the window is functionally the key window.
                let isKey: Bool
                if count == 1 {
                    isKey = true
                } else {
                    isKey = controller.window?.isKeyWindow ?? false
                }
                windows.append([
                    "id": "w\(index + 1)",
                    "title": title,
                    "isKey": isKey
                ])
            }
            if windows.isEmpty {
                windows.append(["id": "w1", "title": "Untitled - Notepad", "isKey": true])
            }
            return windows
        }

        if let data = try? JSONSerialization.data(withJSONObject: result, options: []),
           let json = String(data: data, encoding: .utf8) {
            return HTTPResponse(status: 200, body: json)
        }
        return HTTPResponse(status: 500, body: #"{"error":"serialization"}"#)
    }
}
