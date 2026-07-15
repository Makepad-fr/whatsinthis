import Foundation
import Testing
@testable import whatsinthis

struct OpenPanelAnalyticsTests {
    @Test
    func trackBuildsExpectedRequest() async throws {
        let recorder = AnalyticsRequestRecorder()
        AnalyticsURLProtocolStub.register { request in
            recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data()
            )
        }
        defer { AnalyticsURLProtocolStub.unregister() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AnalyticsURLProtocolStub.self]
        let session = URLSession(configuration: configuration)

        OpenPanelAnalytics.track(
            "app_opened",
            properties: ["source": "unit-test"],
            session: session
        )

        let request = try await recorder.nextRequest()
        #expect(request.url == URL(string: "https://analytics.makepad.fr/api/track"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "openpanel-client-id") == "9984265b-caf4-4fb8-bb4b-6b412a80a29b")
        #expect(request.value(forHTTPHeaderField: "openpanel-sdk-name") == "makepad-ios")
        #expect(request.value(forHTTPHeaderField: "openpanel-sdk-version") == "1")
        #expect(request.value(forHTTPHeaderField: "Origin") == "https://ios.whatsinthis.makepad.fr")

        let body = try Self.requestBodyData(for: request)
        let event = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(event["type"] as? String == "track")

        let payload = try #require(event["payload"] as? [String: Any])
        #expect(payload["name"] as? String == "app_opened")

        let properties = try #require(payload["properties"] as? [String: Any])
        #expect(properties["app"] as? String == "whatsinthis-ios")
        #expect(properties["platform"] as? String == "ios")
        #expect(properties["source"] as? String == "unit-test")
        #expect(properties["app_version"] as? String != nil)
        #expect(properties["app_build"] as? String != nil)
    }

    private static func requestBodyData(for request: URLRequest) throws -> Data {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else {
            throw OpenPanelAnalyticsTestError.missingRequestBody
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer.prefix(count))
            } else if count == 0 {
                break
            } else {
                throw stream.streamError ?? OpenPanelAnalyticsTestError.requestBodyStreamFailed
            }
        }
        return data
    }
}

private final class AnalyticsRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?

    func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        self.request = request
    }

    func nextRequest() async throws -> URLRequest {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let request = recordedRequest() {
                return request
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        throw AnalyticsRequestRecorderError.timeout
    }

    private func recordedRequest() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }

        if let request {
            self.request = nil
            return request
        }
        return nil
    }
}

private enum AnalyticsRequestRecorderError: Error {
    case timeout
}

private enum OpenPanelAnalyticsTestError: Error {
    case missingRequestBody
    case requestBodyStreamFailed
}

private final class AnalyticsURLProtocolStub: URLProtocol {
    private typealias RequestHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var requestHandler: RequestHandler?

    static func register(_ handler: @escaping RequestHandler) {
        lock.lock()
        defer { lock.unlock() }

        requestHandler = handler
    }

    static func unregister() {
        lock.lock()
        defer { lock.unlock() }

        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "analytics.makepad.fr" && request.url?.path == "/api/track"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.currentRequestHandler() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func currentRequestHandler() -> RequestHandler? {
        lock.lock()
        defer { lock.unlock() }

        return requestHandler
    }
}
