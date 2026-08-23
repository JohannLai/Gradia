import Foundation
import SwiftData

@Model
final class LocalRecord {
    @Attribute(.unique) var id: String
    var kind: String
    var payload: Data
    var updatedAt: Date

    init(id: String, kind: String, payload: Data, updatedAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
final class PendingMutation {
    @Attribute(.unique) var requestID: String
    var action: String
    var payload: Data
    var createdAt: Date
    var retryCount: Int
    var lastError: String?

    init(requestID: String = UUID().uuidString, action: String, payload: Data) {
        self.requestID = requestID
        self.action = action
        self.payload = payload
        self.createdAt = .now
        self.retryCount = 0
    }
}

