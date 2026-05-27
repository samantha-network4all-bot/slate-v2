import Foundation
import AppKit

private let serverPortFile: String = {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/Library/Application Support/Slate/test-api.port"
}()

class TestAPIServer {

    static var shared = TestAPIServer()

    private var listener: CFSocket?
    private var port: Int = 0

    private init() {}

    func start() {
        guard ProcessInfo.processInfo.environment["SLATE_TEST_API"] == "1" else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.listen()
        }
    }

    private func listen() {
        var context = CFSocketContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let sock = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                                         CFSocketCallBackType.acceptCallBack.rawValue,
                                         { (s, type, address, data, info) in
                                            if let info = info {
                                                let server = Unmanaged<TestAPIServer>.fromOpaque(info).takeUnretainedValue()
                                                server.acceptConnection(s, address: address)
                                            }
                                         }, &context) else { return }

        CFSocketSetSocketFlags(sock, CFSocketGetSocketFlags(sock) & ~kCFSocketCloseOnInvalidate)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(0).bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)

        let addrData = Data(bytes: &addr, count: MemoryLayout<sockaddr_in>.size) as CFData
        CFSocketSetAddress(sock, addrData)

        let sockName = CFSocketCopyAddress(sock) as Data
        sockName.withUnsafeBytes { ptr in
            let sa = ptr.baseAddress!.assumingMemoryBound(to: sockaddr_in.self)
            let netPort = sa.pointee.sin_port
            self.port = Int(UInt16(bigEndian: netPort))
        }

        // Write port file
        do {
            let dir = URL(fileURLWithPath: serverPortFile).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            let portStr = "\(self.port)\n"
            try portStr.write(toFile: serverPortFile, atomically: true, encoding: .utf8)
        } catch {
            // no-op
        }

        let runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sock, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CFSocketSetSocketFlags(sock, CFSocketGetSocketFlags(sock) | kCFSocketAutomaticallyReenableAcceptCallBack)
        listener = sock
        CFRunLoopRun()
    }

    private func acceptConnection(_ s: CFSocket?, address: CFData?) {
        guard let sock = s else { return }
        let native = CFSocketGetNative(sock)
        let client = accept(native, nil, nil)
        if client < 0 { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.handleClient(client)
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        let fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        guard let data = readRequest(from: fileHandle) else { close(fd); return }

        let response = routeRequest(data)
        writeResponse(to: fd, response: response)
    }

    private func readRequest(from handle: FileHandle) -> Data? {
        var buffer = Data()
        while true {
            if let chunk = try? handle.read(upToCount: 4096) {
                if chunk.count == 0 { break }
                buffer.append(chunk)
                if buffer.count > 65536 { break }
                if let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    return Data(buffer.prefix(through: range.upperBound - 1))
                }
            } else {
                break
            }
        }
        return buffer.isEmpty ? nil : buffer
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
        let path = parts[1]

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
        var msg = "HTTP/1.1 \(response.status) \(response.statusText)\r\n"
        msg += "Content-Type: application/json\r\n"
        msg += "Content-Length: \(response.eventualBody.count)\r\n"
        msg += "Connection: close\r\n"
        msg += "\r\n"
        msg += response.body

        if let raw = msg.data(using: .utf8) {
            raw.withUnsafeBytes { ptr in
                _ = write(fd, ptr.baseAddress, raw.count)
            }
        }
    }
}
