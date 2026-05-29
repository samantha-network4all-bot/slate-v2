import Foundation
import Network
import AppKit

final class TestAPIServer {
    static let shared = TestAPIServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.bimbowate.slate.testapi")

    var port: UInt16 = 0

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: .any)
        } catch {
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.listener?.port {
                    self?.port = port.rawValue
                    self?.writePortFile(port.rawValue)
                }
            case .waiting(let error):
                if let posixError = error as? POSIXError, posixError.code == .EADDRINUSE {
                    break
                }
                break
            case .failed, .cancelled:
                break
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    private func writePortFile(_ port: UInt16) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let slateDir = appSupport.appendingPathComponent("Slate")
        try? FileManager.default.createDirectory(at: slateDir, withIntermediateDirectories: true, attributes: nil)
        let portFile = slateDir.appendingPathComponent("test-api.port")
        let data = Data("\(port)\n".utf8)
        try? data.write(to: portFile, options: .atomic)
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveNextRequest(connection)
    }

    private func receiveNextRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data = data, !data.isEmpty else {
                if !(isComplete || error != nil) {
                    self?.receiveNextRequest(connection)
                }
                return
            }

            guard let request = self.parseHTTPRequest(data) else {
                let response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            let routerResponse = TestAPIServer.shared.processRequest(request)

            var headerString = "HTTP/1.1 \(routerResponse.status)\r\n"
            for (key, value) in routerResponse.headers {
                headerString += "\(key): \(value)\r\n"
            }
            headerString += "Content-Length: \(routerResponse.body.count)\r\n"
            headerString += "Connection: close\r\n\r\n"

            guard var responseData = headerString.data(using: .utf8) else {
                connection.cancel()
                return
            }
            responseData.append(routerResponse.body)

            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    fileprivate func processRequest(_ request: TestAPIRequest) -> TestAPIResponse {
        return TestAPIRouter.shared.dispatch(request)
    }

    private func parseHTTPRequest(_ data: Data) -> TestAPIRequest? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }

        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }

        let method = parts[0]
        let path = parts[1]

        var headers: [String: String] = [:]
        var bodyStart = 0
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            if line.isEmpty {
                bodyStart = i + 1
                break
            }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex])
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key.lowercased()] = value
            }
        }

        var body = Data()
        if bodyStart > 0 && bodyStart < lines.count {
            if let contentLength = headers["content-length"].flatMap(Int.init) {
                if let bodyEnd = raw.range(of: "\r\n\r\n") {
                    let afterHeaders = raw[bodyEnd.upperBound...]
                    body = String(afterHeaders.prefix(contentLength)).data(using: .utf8) ?? Data()
                }
            }
        }

        return TestAPIRequest(method: method, path: path, headers: headers, body: body)
    }
}
