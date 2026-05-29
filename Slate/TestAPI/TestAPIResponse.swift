import Foundation

struct TestAPIResponse {
    let status: Int
    let headers: [String: String]
    let body: Data

    init(status: Int, headers: [String: String] = ["Content-Type": "application/json"], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    static func ok(json: Data) -> TestAPIResponse {
        return TestAPIResponse(status: 200, headers: ["Content-Type": "application/json"], body: json)
    }

    static func notFound(_ req: TestAPIRequest? = nil) -> TestAPIResponse {
        let msg = req.map { "not found: \($0.method) \($0.path)" } ?? "not found"
        let body = Data(#"{"error":"\#(msg)"}"#.utf8)
        return TestAPIResponse(status: 404, body: body)
    }

    static func badRequest(_ message: String) -> TestAPIResponse {
        let body = Data(#"{"error":"\#(message)"}"#.utf8)
        return TestAPIResponse(status: 400, body: body)
    }
}
