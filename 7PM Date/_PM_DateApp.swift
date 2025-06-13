//
//  _PM_DateApp.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI
import AuthenticationServices // Keeping this import as it's likely used by AuthManager
import Combine              // Keeping this import as it's likely used by AuthManager
import UserNotifications // Import UserNotifications
import Firebase // Import Firebase

@main
struct _PM_DateApp: App {
    @StateObject private var authManager = AuthManager()
    @State private var isSplashScreenDone = false // New state variable
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // Add this line

    init() { // Add init if not present, or modify existing one
        FirebaseApp.configure() // Ensure Firebase is configured
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
                return
            }
            if granted {
                print("Notification authorization granted.")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("Notification authorization denied.")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !isSplashScreenDone {
                    // Show SplashScreenView and pass the onFinished closure
                    SplashScreenView(onFinished: {
                        isSplashScreenDone = true
                    })
                } else {
                    // Once splash screen is done, proceed with existing auth logic
                    if authManager.isAuthenticated == true {
                        if authManager.isOnboardingComplete {
                            ContentView()
                        } else {
                            OnboardingStepsView()
                        }
                    } else {
                        // This covers authManager.isAuthenticated == false OR authManager.isAuthenticated == nil
                        // If auth is nil here, it means splash finished before auth was determined,
                        // which shouldn't happen with the new SplashScreenView logic, but SignInView is a safe fallback.
                        SignInView()
                    }
                }
            }
            .environmentObject(authManager)
        }
    }
}

import CloudKit // Import CloudKit

// Add AppDelegate class for notification handling
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Attempt to get AuthManager. This is a bit tricky with property wrappers.
    // A common pattern is to pass it after app launch or use a shared instance.
    // For now, let's assume we can get it or its critical data (userRecordID).
    // This might need adjustment based on how AuthManager is structured and provided.
    // One way: lazy var authManager: AuthManager = (UIApplication.shared.delegate as! _PM_DateApp).authManager
    // However, _PM_DateApp is a struct.
    // Let's assume for now we'll pass the userRecordID directly when calling fetchAndPostMessage or retrieve it from a singleton/global.
    // For the purpose of this subtask, we will simulate obtaining it.

    // TEMPORARY: This would ideally be in AuthManager.swift
    // extension AuthManager {
    //    static let shared = AuthManager() // Ensure AuthManager() is accessible and makes sense as shared.
    // }
    // For the purpose of this file to compile, let's add a dummy shared if not available.
    // This is a MAJOR simplification. In a real app, AuthManager dependency injection or proper singleton access is key.
    // If AuthManager is an @StateObject in _PM_DateApp, it's not directly accessible via a static shared here.
    // We'll proceed with the assumption that a mechanism like a true singleton or environment object access
    // would be established in a broader context. For now, a placeholder:
    private static var _sharedAuthManagerInstance = AuthManager() // Create a static instance for the placeholder
    static var sharedAuthManager: AuthManager { // Provide a static accessor
        // In a real app, this would be the actual shared instance.
        // For now, it's a new instance or one managed by _PM_DateApp if passed.
        // This is a conceptual placeholder for AuthManager.shared.userRecordID?.recordName
        // It's highly likely this will not correctly reflect the logged-in user without further setup.
        return _sharedAuthManagerInstance
    }


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(tokenString)")
        // You might want to use Auth.auth().setAPNSToken(deviceToken, type: .unknown) if using Firebase for Auth/FCM

        // Subscribe to CloudKit for new messages
        subscribeToNewMessages()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func subscribeToNewMessages() {
        let publicDatabase = CKContainer.default().publicCloudDatabase
        let subscriptionID = "new-chat-message-subscription"

        // Check if subscription already exists
        publicDatabase.fetch(withSubscriptionID: subscriptionID) { existingSubscription, error in
            if existingSubscription != nil {
                print("Subscription with ID '\(subscriptionID)' already exists.")
                return
            }

            // If error is not 'unknown item', then it's an actual error
            if let error = error as? CKError, error.code != .unknownItem {
                print("Error checking for existing subscription: \(error.localizedDescription)")
                // Decide if you want to proceed or return. For this example, we'll try to create one anyway.
            }

            let predicate = NSPredicate(value: true)
            let subscription = CKQuerySubscription(recordType: "ChatMessage",
                                                   predicate: predicate,
                                                   subscriptionID: subscriptionID,
                                                   options: .firesOnRecordCreation)

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            // Requesting recordName (CKRecord.ID.recordName) as it's simpler.
            // CloudKit sends the CKRecord.ID of the modified record in the payload.
            // We can then fetch the record if more details are needed.
            // For silent pushes, specific desiredKeys might not be strictly necessary if shouldSendContentAvailable is true,
            // as the primary goal is to wake the app. The CKRecord.ID is usually part of the payload.
            // If you need specific fields directly in the notification payload (not recommended for silent pushes to avoid large payloads):
            // notificationInfo.desiredKeys = ["senderId", "text"] // Example keys
            subscription.notificationInfo = notificationInfo

            publicDatabase.save(subscription) { savedSubscription, error in
                if let error = error {
                    print("Failed to save subscription: \(error.localizedDescription)")
                } else {
                    print("Successfully subscribed to new chat messages with ID: \(savedSubscription?.subscriptionID ?? "N/A")")
                }
            }
        }
    }

    // Handle incoming notifications while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge]) // Or [.list, .banner, .sound, .badge] based on iOS version and desired behavior
    }

    // Handle user's interaction with the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Process the notification (e.g., navigate to a specific screen)
        let userInfo = response.notification.request.content.userInfo
        print("Received notification with userInfo: \(userInfo)")

        // Check if it's a CloudKit notification
        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) { // Renamed for clarity
            print("Received CloudKit notification type: \(ckNotification.notificationType.rawValue)")
            if ckNotification.notificationType == .query {
                if let queryNotification = ckNotification as? CKQueryNotification,
                   queryNotification.subscriptionID == "new-chat-message-subscription",
                   let recordID = queryNotification.recordID {

                    print("Received query notification for new chat message with Record ID: \(recordID.recordName)")
                    // Fetch the actual message content
                    // We need the current user's record name to determine `isFromCurrentUser`
                    // This is a placeholder for how you might get the AuthManager instance or userRecordID.
                    let currentUserRecordName = AppDelegate.sharedAuthManager.userRecordID?.recordName // Using the placeholder

                    fetchAndPostChatMessage(recordID: recordID, currentUserRecordName: currentUserRecordName, originalCompletionHandler: completionHandler)
                    return // IMPORTANT: originalCompletionHandler will be called inside fetchAndPostChatMessage
                }
            }
        }
        // If not a handled CloudKit notification or some other issue, call originalCompletionHandler.
        completionHandler() // Default completion if not handled
    }

    func fetchAndPostChatMessage(recordID: CKRecord.ID, currentUserRecordName: String?, originalCompletionHandler: @escaping () -> Void) {
        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.fetch(withRecordID: recordID) { fetchedRecord, error in
            defer {
                // Ensure the original completion handler from didReceive is always called.
                // This is critical for the system to know the app has processed the notification.
                originalCompletionHandler()
            }

            if let error = error {
                print("Error fetching record with ID \(recordID.recordName): \(error.localizedDescription)")
                return
            }

            guard let record = fetchedRecord else {
                print("Fetched record is nil for ID \(recordID.recordName)")
                return
            }

            print("Successfully fetched record: \(record.recordID.recordName)")
            // Ensure we are using the ChatMessage struct from SpeedDatingView.swift
            // This requires SpeedDatingView.swift to be compiled and its types available.
            // The ChatMessage initializer is now the default memberwise one, as we removed the custom one from the placeholder.
            // We need to construct it field by field.
            let text = record["text"] as? String ?? ""
            let isFromCurrentUser = record.creatorUserRecordID?.recordName == currentUserRecordName
            let chatSessionRef = record["chatSessionRef"] as? CKRecord.Reference

            // Create the ChatMessage object using the definition from SpeedDatingView.swift
            let chatMessage = ChatMessage(
                id: record.recordID,
                text: text,
                isFromCurrentUser: isFromCurrentUser,
                chatSessionRef: chatSessionRef
            )
            // The old placeholder ChatMessage had a failable init ChatMessage(record: record, currentUserRecordName: currentUserRecordName)
            // The new one in SpeedDatingView does not have this custom init, so we construct manually.

            print("Successfully created ChatMessage object: \(chatMessage.id.recordName)")
            NotificationCenter.default.post(
                name: .DidReceiveNewChatMessage, // This name should be defined in SpeedDatingView and accessible here
                object: nil,
                userInfo: ["message": chatMessage] // Key changed to "message" as per subtask
            )
            print("Posted DidReceiveNewChatMessage notification for message ID: \(chatMessage.id.recordName)")
            // The subtask mentioned calling completionHandler with .newData.
                // That applies to application:didReceiveRemoteNotification:fetchCompletionHandler:,
                // not userNotificationCenter:didReceive:withCompletionHandler:.
                // For userNotificationCenter:didReceive:withCompletionHandler:, we just call the empty closure
                // completionHandler(), which is done in the defer block.
            // } else { // This 'else' is not needed if ChatMessage construction is direct
            //    print("Failed to create ChatMessage from fetched record: \(record.recordID.recordName)")
            // }
        }
    }
}
// Crucial: Ensure Notification.Name.DidReceiveNewChatMessage is accessible.
// It's defined in SpeedDatingView.swift. If _PM_DateApp.swift doesn't automatically
// see it due to Swift's compilation model (e.g. if they are in different targets
// without proper import), this might be an issue. For now, assume it's accessible.
// If not, it might need to be defined in a more globally accessible place or _PM_DateApp.swift.
// For this exercise, we assume it's fine.
