import SwiftUI
import Combine // For potential future use with @ObservedObject or @StateObject if messages array becomes more complex

struct ChatView: View {
    let sessionID: String // ID of the current chat session
    @State private var messages: [ChatMessage] = []
    @State private var messageText: String = ""

    // Access AuthManager through EnvironmentObject if it's provided higher up
    // For this subtask, we assume ChatMessage.isFromCurrentUser is handled
    // during its creation in AppDelegate or via a shared AuthManager instance.
    // @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack {
            List(messages) { message in
                HStack {
                    if message.isFromCurrentUser {
                        Spacer()
                        Text(message.text)
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(Color.white)
                            .cornerRadius(10)
                    } else {
                        Text(message.text)
                            .padding(10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        Spacer()
                    }
                }
                .id(message.id) // Ensure each row is uniquely identifiable for updates
            }

            HStack {
                TextField("Enter message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    // Send message logic (not part of this subtask)
                    // For testing, you could manually create and add a message here
                }
            }
            .padding()
        }
        .navigationTitle("Chat")
        .onAppear {
            subscribeToNewMessages()
            // Load initial messages for this sessionID (not part of this subtask)
        }
        .onDisappear {
            unsubscribeFromNewMessages()
        }
    }

    private func subscribeToNewMessages() {
        NotificationCenter.default.addObserver(
            forName: .DidReceiveNewChatMessage,
            object: nil,
            queue: .main) { notification in
                handleNewMessageNotification(notification)
        }
        print("ChatView for session \(sessionID) subscribed to DidReceiveNewChatMessage.")
    }

    private func unsubscribeFromNewMessages() {
        NotificationCenter.default.removeObserver(self, name: .DidReceiveNewChatMessage, object: nil)
        print("ChatView for session \(sessionID) unsubscribed from DidReceiveNewChatMessage.")
    }

    private func handleNewMessageNotification(_ notification: Notification) {
        guard let newMessage = notification.userInfo?["chatMessage"] as? ChatMessage else {
            print("Failed to extract ChatMessage from notification.")
            return
        }

        print("ChatView received new message: \(newMessage.id) for session: \(newMessage.chatSessionID)")
        // Only append if the message belongs to the current chat session
        if newMessage.chatSessionID == self.sessionID {
            // Avoid duplicates, though CloudKit subscription should ideally only fire once per creation
            if !messages.contains(where: { $0.id == newMessage.id }) {
                self.messages.append(newMessage)
                // Sort messages by timestamp if needed, or assume they arrive in order
                // self.messages.sort(by: { $0.timestamp < $1.timestamp })
                print("New message \(newMessage.id) added to ChatView session \(self.sessionID).")
            } else {
                print("Duplicate message \(newMessage.id) for session \(self.sessionID) not added.")
            }
        } else {
            print("Message \(newMessage.id) (session \(newMessage.chatSessionID)) not for current ChatView session \(self.sessionID).")
        }
    }
}

// Dummy ChatView for Previews
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(sessionID: "previewSession123")
    }
}
