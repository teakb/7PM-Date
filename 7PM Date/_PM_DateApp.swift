//
//  _PM_DateApp.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI
import AuthenticationServices // Keeping this import as it's likely used by AuthManager
import Combine              // Keeping this import as it's likely used by AuthManager
import UserNotifications     // New import for notifications
import UIKit                 // For UIApplicationDelegateAdaptor
import CloudKit              // Added this import to resolve CK* types and symbols

// AppDelegate for handling remote notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register for remote notifications
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle CloudKit notifications
        guard let userInfoDict = userInfo as? [String: NSObject] else {
            completionHandler(.noData)
            return
        }
        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfoDict) {
            if let queryNotification = ckNotification as? CKQueryNotification {
                // Handle the notification based on record type
                if let recordType = queryNotification.recordFields?["recordType"] as? String {
                    var notificationName: NSNotification.Name?
                    if recordType == "ChatMessage" {
                        notificationName = NSNotification.Name("NewChatMessage")
                    } else if recordType == "ChatDecision" {
                        notificationName = NSNotification.Name("NewChatDecision")
                    }
                    if let notificationName = notificationName,
                       let fields = queryNotification.recordFields as? [String: Any] {
                        NotificationCenter.default.post(name: notificationName, object: nil, userInfo: fields)
                        completionHandler(.newData)
                        return
                    }
                }
            }
        }
        completionHandler(.noData)
    }
    
    // Optional: Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct _PM_DateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate  // Integrate AppDelegate
    @StateObject private var authManager = AuthManager()
    @State private var isSplashScreenDone = false // New state variable

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
            .onAppear {
                requestNotificationPermission()
                setupCloudKitSubscriptions()
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func setupCloudKitSubscriptions() {
        // Subscribe to new ChatMessage records
        let messagePredicate = NSPredicate(value: true) // Subscribe to all, filter client-side if needed
        let messageSubscription = CKQuerySubscription(recordType: "ChatMessage", predicate: messagePredicate, options: .firesOnRecordCreation)
        messageSubscription.notificationInfo = CKSubscription.NotificationInfo()
        messageSubscription.notificationInfo?.alertBody = "New message received"
        messageSubscription.notificationInfo?.shouldSendContentAvailable = true // Silent push for background fetch

        let publicDB = CKContainer.default().publicCloudDatabase
        publicDB.save(messageSubscription) { subscription, error in
            if let error = error {
                print("Error saving ChatMessage subscription: \(error.localizedDescription)")
            }
        }
        
        // Subscribe to ChatDecision for mutual matches
        let decisionPredicate = NSPredicate(format: "didConnect == 1") // Fires when a decision is yes
        let decisionSubscription = CKQuerySubscription(recordType: "ChatDecision", predicate: decisionPredicate, options: .firesOnRecordCreation)
        decisionSubscription.notificationInfo = CKSubscription.NotificationInfo()
        decisionSubscription.notificationInfo?.alertBody = "New mutual match!"
        decisionSubscription.notificationInfo?.shouldSendContentAvailable = true

        publicDB.save(decisionSubscription) { subscription, error in
            if let error = error {
                print("Error saving ChatDecision subscription: \(error.localizedDescription)")
            }
        }
        
        // Note: For dynamic sessionRef filtering, you may need to create subscriptions per active chat session.
        // This can be done when entering a chat: create a subscription with predicate NSPredicate(format: "sessionRef == %@", sessionRef)
        // And delete the subscription when leaving the chat to avoid quota issues.
    }
}
