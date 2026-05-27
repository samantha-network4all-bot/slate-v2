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

    static func handle(method: String, path: String, query: String?, body: String?) -> HTTPResponse {
        switch (method, path) {

        case ("GET", "/healthz"):
            return HTTPResponse(status: 200, body: #"{"ok":true}"#)

        case ("GET", "/windows"):
            return windowsResponse()

        case ("GET", "/screenshot"):
            return screenshotResponse()

        case ("GET", "/text"):
            return textResponse(query: query)

        case ("POST", "/type"):
            return typeResponse(body: body)

        case ("POST", "/shutdown"):
            return shutdownResponse()

        default:
            return HTTPResponse(status: 404, body: #"{"error":"not found"}"#)
        }
    }

    // MARK: - Helper: parse query string

    private static func parseQuery(_ query: String?) -> [String: String] {
        guard let query = query, !query.isEmpty else { return [:] }
        var result: [String: String] = [:]
        let pairs = query.components(separatedBy: "&")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                result[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
            }
        }
        return result
    }

    // MARK: - Helper: window lookup

    private static func resolveController(windowId: String?) -> SlateWindowController? {
        let controllers = DocumentController.shared.windowControllers
        if let id = windowId, !id.isEmpty {
            // "w1" → index 0, "w2" → index 1, etc.
            if let indexStr = id.dropFirst().description as String?,
               let index = Int(indexStr), index >= 1 && index <= controllers.count {
                return controllers[index - 1]
            }
            return nil
        }
        // No windowId: use key window or last controller (most recently created)
        if let key = controllers.first(where: { $0.window?.isKeyWindow == true }) {
            return key
        }
        return controllers.last
    }

    // MARK: - GET /text

    private static func textResponse(query: String?) -> HTTPResponse {
        let params = parseQuery(query)
        let result = DispatchQueue.main.sync {
            guard let controller = resolveController(windowId: params["windowId"]) else {
                return nil as String?
            }
            return controller.editor.string
        }
        guard let text = result else {
            return HTTPResponse(status: 404, body: #"{"error":"window not found"}"#)
        }
        let jsonObj = ["text": text]
        if let data = try? JSONSerialization.data(withJSONObject: jsonObj, options: []),
           let json = String(data: data, encoding: .utf8) {
            return HTTPResponse(status: 200, body: json)
        }
        return HTTPResponse(status: 500, body: #"{"error":"serialization"}"#)
    }

    // MARK: - POST /type

    private static func typeResponse(body: String?) -> HTTPResponse {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let text = json["text"] as? String else {
            return HTTPResponse(status: 400, body: #"{"error":"bad request"}"#)
        }
        let windowId = json["windowId"] as? String

        let ok = DispatchQueue.main.sync {
            guard let controller = resolveController(windowId: windowId) else {
                return false
            }
            controller.editor.string = text
            NotificationCenter.default.post(name: NSText.didChangeNotification, object: controller.editor)
            return true
        }

        if ok {
            return HTTPResponse(status: 200, body: #"{"ok":true}"#)
        }
        return HTTPResponse(status: 404, body: #"{"error":"window not found"}"#)
    }

    // MARK: - POST /shutdown

    private static func shutdownResponse() -> HTTPResponse {
        DispatchQueue.main.async {
            try? FileManager.default.removeItem(atPath: testAPIPortFilePath)
            NSApp.terminate(nil)
        }
        return HTTPResponse(status: 200, body: #"{"ok":true}"#)
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
            let controllers = DocumentController.shared.windowControllers
            let count = controllers.count
            guard let controller = controllers.first else {
                return ["id": "w1", "title": "Untitled - Notepad", "isKey": true] as [String: Any]
            }
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
            return ["id": "w1", "title": title, "isKey": isKey] as [String: Any]
        }

        if let data = try? JSONSerialization.data(withJSONObject: result, options: []),
           let json = String(data: data, encoding: .utf8) {
            return HTTPResponse(status: 200, body: json)
        }
        return HTTPResponse(status: 500, body: #"{"error":"serialization"}"#)
    }
}
