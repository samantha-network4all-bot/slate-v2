import Foundation
import AppKit

private let serverPortFile: String = {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/Library/Application Support/Slate/test-api.port"
}()

class TestAPIServer {

    static var shared = TestAPIServer()

    private var listenerFD: Int32 = -1
    private var port: Int = 0

    private init() {}

    func start() {
        guard ProcessInfo.processInfo.environment["SLATE_TEST_API"] == "1" else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.listen()
        }
    }

    private func listen() {
        // Create socket
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        self.listenerFD = fd

        // Allow address reuse
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(0).bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)

        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bindResult = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, addrSize)
            }
        }
        guard bindResult == 0 else { close(fd); return }

        // Listen
        guard Darwin.listen(fd, 8) == 0 else { close(fd); return }

        // Get port
        var actualAddr = sockaddr_in()
        var actualLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let portResult = withUnsafeMutablePointer(to: &actualAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &actualLen)
            }
        }
        guard portResult == 0 else { close(fd); return }
        self.port = Int(UInt16(bigEndian: actualAddr.sin_port))

        // Write port file
        do {
            let dir = URL(fileURLWithPath: serverPortFile).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            let portStr = "\(self.port)\n"
            try portStr.write(toFile: serverPortFile, atomically: true, encoding: .utf8)
        } catch {
            // no-op
        }

        // Accept loop
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 { break }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(client)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        // Read request data using low-level read
        var buffer = Data()
        var tempBuf = [UInt8](repeating: 0, count: 4096)
        let delimiter = Data("\r\n\r\n".utf8)

        while buffer.count <= 65536 {
            let bytesRead = tempBuf.withUnsafeMutableBytes { ptr in
                read(fd, ptr.baseAddress, 4096)
            }
            if bytesRead <= 0 { break }
            buffer.append(contentsOf: tempBuf.prefix(Int(bytesRead)))
            if buffer.range(of: delimiter) != nil {
                break
            }
        }

        guard !buffer.isEmpty else { return }

        let response = routeRequest(buffer)
        writeResponse(to: fd, response: response)
    }

    private func routeRequest(_ data: Data) -> HTTPResponse {
        guard let requestString = String(data: data, encoding: .utf8) else {
            return HTTPResponse(status: 400, body: #"{"error":"bad request"}"#)
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return HTTPResponse(status: 400, body: #"{"error":"bad request"}"#)
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 3 else {
            return HTTPResponse(status: 400, body: #"{"error":"bad request"}"#)
        }

        let method = parts[0]
        let rawPath = parts[1]
        let path = rawPath.components(separatedBy: "?").first ?? rawPath

        var body: String? = nil
        if let br = data.range(of: Data("\r\n\r\n".utf8)) {
            let bodyStart = br.upperBound
            if bodyStart < data.count {
                body = String(data: data.suffix(from: bodyStart), encoding: .utf8)
            }
        }

        return TestAPIRoutes.handle(method: method, path: path, body: body)
    }

    private func writeResponse(to fd: Int32, response: HTTPResponse) {
        let body: Data
        if let binary = response.binaryBody {
            body = binary
        } else {
            body = response.eventualBody.data(using: .utf8) ?? Data()
        }

        var header = "HTTP/1.1 \(response.status) \(response.statusText)\r\n"
        header += "Content-Type: \(response.contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        if let headerData = header.data(using: .utf8) {
            headerData.withUnsafeBytes { ptr in
                _ = write(fd, ptr.baseAddress, headerData.count)
            }
        }
        body.withUnsafeBytes { ptr in
            _ = write(fd, ptr.baseAddress, body.count)
        }
    }
}
