//
//  ContentView.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager // Keep this if needed by sub-views, or remove if not

    var body: some View {
        TabView {
            SpeedDatingView()
                .tabItem {
                    Label("Speed Dating", systemImage: "heart.fill")
                }

            MatchesView()
                .tabItem {
                    Label("Matches", systemImage: "list.star")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager()) // Add AuthManager for preview if it's used by ContentView or its children
}
