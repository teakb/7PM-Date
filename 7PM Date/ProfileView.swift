//
//  ProfileView.swift
//  7PM Date
//
//  Created by Austin Berger on 6/12/25.
//

//
//  ProfileView.swift
//  7PM Date
//
//  Created by AI Assistant on 2025-06-12
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 20) { // Added spacing for better layout
            Text("Profile View")
                .font(.title)

            Button("Delete Profile (For Testing)") {
                authManager.deleteAccount()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)

            Button("Logout") {
                authManager.signOut() // Assuming this method exists
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer() // Keep spacer at the bottom of button list
        }
        .padding() // Add padding to the VStack
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
