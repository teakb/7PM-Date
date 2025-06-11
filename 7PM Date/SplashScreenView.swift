//
//  SplashScreenView.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isActive = false // Controls opacity and fade-out animation

    @State private var isMinimumTimeElapsed = false
    @State private var isAuthStatusKnown = false

    var onFinished: () -> Void // Callback for when the splash screen is done

    var body: some View {
        ZStack {
            // New background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.red, Color.yellow]), // Changed colors
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content with AnimatedClockView
            VStack {
                AnimatedClockView() // Using default target of 7 PM
                    .frame(width: 100, height: 100) // Giving it a slightly larger frame than the SF Symbol, adjust as needed
                    .padding()
                Text("7PM Date")
                    .font(.largeTitle)
                    .bold()
            }
        }
        .opacity(isActive ? 0 : 1)
        // The animation is triggered when 'isActive' changes.
        // When isActive becomes true, the view fades out.
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .onAppear {
            // Start a 7-second timer for minimum display time
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                isMinimumTimeElapsed = true
            }
            
            // Initial check for auth status
            if authManager.isAuthenticated != nil {
                isAuthStatusKnown = true
            }
        }
        // Monitor authManager.isAuthenticated for changes
        .onChange(of: authManager.isAuthenticated) { newValue in
            if newValue != nil {
                isAuthStatusKnown = true
            }
        }
        // Monitor combined state to trigger fade-out
        .onChange(of: [isMinimumTimeElapsed, isAuthStatusKnown]) { newValues in
            let canProceed = newValues[0] // isMinimumTimeElapsed
            let authKnown = newValues[1] // isAuthStatusKnown
            
            if canProceed && authKnown && !isActive {
                isActive = true // Start fade-out
                // Call onFinished after the animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Matches animation duration
                    onFinished()
                }
            }
        }
    }
}

// Update preview to provide a dummy onFinished and AuthManager
#Preview {
    SplashScreenView(onFinished: { print("Splash finished") })
        .environmentObject(AuthManager())
}
