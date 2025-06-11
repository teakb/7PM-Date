//
//  _PM_DateApp.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI
import AuthenticationServices // Keeping this import as it's likely used by AuthManager
import Combine              // Keeping this import as it's likely used by AuthManager

@main
struct _PM_DateApp: App {
    // Declaring AuthManager as a StateObject to manage authentication state
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            // Using a Group to conditionally display views based on authentication and onboarding status.
            // This is the complete authentication flow logic.
            Group {
                if authManager.isAuthenticated == nil {
                    // AuthManager is still determining status (e.g., during checkInitialCloudKitStatus)
                    // Show a splash screen while the status is being determined.
                    SplashScreenView()
                } else if authManager.isAuthenticated == true {
                    // User is authenticated. Now check if onboarding is complete.
                    if authManager.isOnboardingComplete {
                        // User is authenticated and onboarding is complete, show the main content view.
                        ContentView()
                    } else {
                        // User is authenticated but onboarding is not complete, show onboarding steps.
                        OnboardingStepsView()
                    }
                } else {
                    // User is not authenticated (iCloud or app-specific authentication failed or not started).
                    // Show the sign-in view.
                    SignInView()
                }
            }
            // Injecting the AuthManager into the environment so child views can access it.
            .environmentObject(authManager)
        }
    }
}
