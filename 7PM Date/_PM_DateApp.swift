//
//  _PM_DateApp.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI
import AuthenticationServices
import Combine

@main
struct _PM_DateApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated == nil {
                    // Still checking authentication status (e.g., initial fetchUserRecordID)
                    SplashScreenView()
                } else if authManager.isAuthenticated == true {
                    if authManager.isOnboardingComplete {
                        ContentView() // Existing user, onboarding complete
                    } else {
                        OnboardingStepsView() // New user, needs onboarding
                    }
                } else {
                    SignInView() // Not authenticated
                }
            }
            .environmentObject(authManager)
        }
    }
}
