//
//  _PM_DateApp.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI
<<<<<<< HEAD

@main
struct _PM_DateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
=======
import AuthenticationServices
import Combine

@main
struct _PM_DateApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated == nil {
                    // AuthManager is still determining status (e.g., during checkInitialCloudKitStatus)
                    SplashScreenView() // Show splash screen while determining
                } else if authManager.isAuthenticated == true {
                    if authManager.isOnboardingComplete {
                        ContentView() // Existing user, onboarding complete
                    } else {
                        OnboardingStepsView() // New user or existing user needs onboarding
                    }
                } else {
                    SignInView() // Not authenticated (iCloud or app-specific)
                }
            }
            .environmentObject(authManager)
>>>>>>> 879be4f (Initial Commit)
        }
    }
}
