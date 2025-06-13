import CloudKit
import SwiftUI // For identifiable if needed

// Define the Notification Name
extension Notification.Name {
    static let DidReceiveNewChatMessage = Notification.Name("DidReceiveNewChatMessage")
}

struct ChatMessage: Identifiable, Equatable {
    let id: String // CKRecord.ID.recordName
    let text: String
    let timestamp: Date
    let senderRecordName: String // Store sender's record name for simplicity
    let chatSessionID: String // To which chat session this message belongs
    var isFromCurrentUser: Bool = false // Placeholder, to be determined

    init?(record: CKRecord, currentUserRecordName: String?) {
        guard let text = record["text"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let senderRef = record["senderRef"] as? CKRecord.Reference,
              let chatSessionRef = record["chatSessionRef"] as? CKRecord.Reference else {
            print("Failed to initialize ChatMessage from CKRecord: missing essential fields")
            return nil
        }

        self.id = record.recordID.recordName
        self.text = text
        self.timestamp = timestamp
        self.senderRecordName = senderRef.recordID.recordName
        self.chatSessionID = chatSessionRef.recordID.recordName

        if let currentUserName = currentUserRecordName {
            self.isFromCurrentUser = (self.senderRecordName == currentUserName)
        }
    }

    // Dummy initializer for previews or testing if needed
    init(id: String, text: String, timestamp: Date, senderRecordName: String, chatSessionID: String, isFromCurrentUser: Bool) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.senderRecordName = senderRecordName
        self.chatSessionID = chatSessionID
        self.isFromCurrentUser = isFromCurrentUser
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}
