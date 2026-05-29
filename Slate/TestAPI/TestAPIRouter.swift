import Foundation

protocol TestAPIControllerRoutes {
    static var routePrefix: String { get }
    func registerRoutes(on router: TestAPIRouter)
}

final class TestAPIRouter {
    static let shared = TestAPIRouter()
    private var handlers: [String: (TestAPIRequest) -> TestAPIResponse] = [:]

    func register<C: TestAPIControllerRoutes>(controller: C) {
        controller.registerRoutes(on: self)
    }

    func get(prefix: String, path: String, _ handler: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let key = "GET /\(prefix)\(path)"
        handlers[key] = handler
    }

    func post(prefix: String, path: String, _ handler: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let key = "POST /\(prefix)\(path)"
        handlers[key] = handler
    }

    /// Register a route at top-level (no prefix). Only for /healthz.
    func get(path: String, _ handler: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let key = "GET \(path)"
        handlers[key] = handler
    }

    /// Register a route at top-level (no prefix). Only for /app/shutdown.
    func post(path: String, _ handler: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let key = "POST \(path)"
        handlers[key] = handler
    }

    func dispatch(_ req: TestAPIRequest) -> TestAPIResponse {
        let key = "\(req.method) \(req.path)"
        if let handler = handlers[key] {
            return handler(req)
        }
        return .notFound(req)
    }
}
