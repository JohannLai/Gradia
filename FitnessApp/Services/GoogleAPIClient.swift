import Foundation

actor GoogleAPIClient {
    static let shared = GoogleAPIClient()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = SyncTransferPolicy.singleRequestTimeout
            configuration.timeoutIntervalForResource = SyncTransferPolicy.resourceTimeout
            configuration.waitsForConnectivity = false
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    struct BatchItem: Sendable {
        let requestID: String
        let action: String
        let payload: Data
    }

    struct BatchResult: Sendable {
        let requestID: String
        let error: String?

        var succeeded: Bool { error == nil }
    }

    func send(endpoint: URL, token: String, action: String, requestID: String, payload: Data) async throws {
        _ = try await request(
            endpoint: endpoint,
            token: token,
            action: action,
            requestID: requestID,
            payload: try JSONSerialization.jsonObject(with: payload),
            timeout: action == "uploadMealPhoto"
                ? SyncTransferPolicy.photoRequestTimeout
                : SyncTransferPolicy.singleRequestTimeout
        )
    }

    func sendBatch(endpoint: URL, token: String, items: [BatchItem]) async throws -> [BatchResult] {
        let itemObjects = try items.map { item -> [String: Any] in
            [
                "requestId": item.requestID,
                "action": item.action,
                "payload": try JSONSerialization.jsonObject(with: item.payload)
            ]
        }
        let response = try await request(
            endpoint: endpoint,
            token: token,
            action: "syncBatch",
            requestID: UUID().uuidString,
            payload: ["items": itemObjects],
            timeout: SyncTransferPolicy.batchRequestTimeout
        )
        guard let data = response["data"] as? [String: Any],
              let results = data["results"] as? [[String: Any]] else {
            throw GoogleAPIError.invalidResponse
        }
        return results.compactMap { result in
            guard let requestID = result["requestId"] as? String else { return nil }
            let ok = result["ok"] as? Bool == true
            let message = (result["error"] as? [String: Any])?["message"] as? String
            return BatchResult(requestID: requestID, error: ok ? nil : (message ?? "服务端写入失败"))
        }
    }

    private func request(
        endpoint: URL,
        token: String,
        action: String,
        requestID: String,
        payload: Any,
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "token": token,
            "action": action,
            "requestId": requestID,
            "payload": payload
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAPIError.invalidResponse
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["ok"] as? Bool == true else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = (object?["error"] as? [String: Any])?["message"] as? String
                ?? object?["error"] as? String
                ?? "Google Apps Script 返回失败"
            throw GoogleAPIError.server(message)
        }
        return object
    }
}

enum SyncTransferPolicy {
    static let regularBatchSize = 8
    static let compatibilityConcurrency = 2
    static let singleRequestTimeout: TimeInterval = 20
    static let batchRequestTimeout: TimeInterval = 35
    static let photoRequestTimeout: TimeInterval = 45
    static let resourceTimeout: TimeInterval = 50
    static let staleSyncInterval: TimeInterval = 90
}

enum SyncRetryPolicy {
    static func delay(forRetryCount retryCount: Int) -> TimeInterval {
        guard retryCount > 0 else { return 0 }
        return min(300, pow(2, Double(min(retryCount, 16))))
    }
}

enum GoogleAPIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Google 服务响应无效"
        case .server(let message): message
        }
    }
}

enum SyncErrorPresenter {
    static func friendlyMessage(_ message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("unauthorized") { return "访问密钥不正确" }
        if lowercased.contains("timed out") || lowercased.contains("timeout") { return "连接超时，请检查网络或更新备份服务" }
        if lowercased.contains("not connected") || lowercased.contains("offline") { return "当前没有网络连接" }
        if lowercased.contains("schema is not initialized") { return "备份服务尚未初始化" }
        if lowercased.contains("header mismatch") { return "Google 表格结构需要更新" }
        return message
    }
}
