//
//  ContentView.swift
//  7PM Date
//
//  Created by Austin Berger on 6/10/25.
//


import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack {
            Text("Welcome to 7PM Date!")
                .font(.title)
                .padding()

            Button("Delete Profile (For Testing)") {
                authManager.deleteAccount()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
    }
}

