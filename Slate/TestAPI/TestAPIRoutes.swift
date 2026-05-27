import Foundation

// MARK: - HTTPResponse

struct HTTPResponse {
    let status: Int
    let body: String

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

        default:
            return HTTPResponse(status: 404, body: #"{"error":"not found"}"#)
        }
    }

    private static func windowsResponse() -> HTTPResponse {
        var windows: [[String: Any]] = []
        let controllers = DocumentController.shared.windowControllers
        for (index, controller) in controllers.enumerated() {
            let title = controller.window?.title ?? "Untitled - Notepad"
            let isKey = controller.window?.isKeyWindow ?? false
            windows.append([
                "id": "w\(index + 1)",
                "title": title,
                "isKey": isKey
            ])
        }
        if windows.isEmpty {
            windows.append(["id": "w1", "title": "Untitled - Notepad", "isKey": true])
        }

        if let data = try? JSONSerialization.data(withJSONObject: windows, options: []),
           let json = String(data: data, encoding: .utf8) {
            return HTTPResponse(status: 200, body: json)
        }
        return HTTPResponse(status: 500, body: #"{"error":"serialization"}"#)
    }
}
