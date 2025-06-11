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
        }
    }
}
