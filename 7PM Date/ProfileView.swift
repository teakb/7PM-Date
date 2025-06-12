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
import UIKit
import CloudKit

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name: String = ""
    @State private var age: Int = 0
    @State private var gender: String = ""
    @State private var cities: [String] = []
    @State private var photos: [UIImage] = []
    @State private var desiredAgeRange: ClosedRange<Int> = 18...99
    @State private var desiredGenders: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        ProgressView("Loading Profile...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let errorMessage = errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        // TabView Photo Gallery
                        if !photos.isEmpty {
                            TabView {
                                ForEach(photos, id: \.self) { uiImage in
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit() // Ensure the whole image is visible
                                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow it to expand
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic)) // Swipeable pages with indicators
                            .frame(height: 300) // Prominent height for the gallery
                            .background(Color(UIColor.systemGray6)) // Background for the TabView area
                            .cornerRadius(12) // Optional: for rounded corners
                            .padding(.bottom) // Space below the gallery
                        } else {
                            // Placeholder for when no photos are available
                            VStack { // Use VStack for centering content within the placeholder
                                Image(systemName: "photo.on.rectangle.angled") // Or another suitable icon
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(UIColor.systemGray2))
                                Text("No photos available.")
                                    .font(.headline)
                                    .foregroundColor(Color(UIColor.systemGray))
                            }
                            .frame(height: 300) // Match the TabView height
                            .frame(maxWidth: .infinity) // Ensure it takes full width like TabView
                            .background(Color(UIColor.systemGray6)) // Match the TabView background
                            .cornerRadius(12) // Match the TabView cornerRadius
                            .padding(.bottom) // Match the TabView padding
                        }

                        Divider().padding(.bottom, 10) // Divider after photos (or placeholder)

                        // Profile Details Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text(name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .padding(.bottom, 5) // Small padding after name

                            HStack {
                                Text("Age: \(age)")
                                Spacer()
                                Text("Gender: \(gender)")
                            }
                            .font(.title3)
                            .padding(.bottom, 10) // Padding after age/gender HStacks

                            VStack(alignment: .leading, spacing: 3) { // Reduced spacing for headline-subheadline
                                Text("Interested in cities:")
                                    .font(.headline)
                                Text(cities.isEmpty ? "Not specified" : cities.joined(separator: ", "))
                                    .font(.subheadline)
                            }
                            .padding(.bottom, 10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Looking for ages:")
                                    .font(.headline)
                                Text("\(desiredAgeRange.lowerBound) - \(desiredAgeRange.upperBound) years old")
                                    .font(.subheadline)
                            }
                            .padding(.bottom, 10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Interested in genders:")
                                    .font(.headline)
                                Text(desiredGenders.isEmpty ? "Not specified" : desiredGenders.joined(separator: ", "))
                                    .font(.subheadline)
                            }
                        }
                        .padding(.bottom, 20) // More padding after details, before buttons
                        
                        // Action Buttons VStack
                        VStack(spacing: 10) {
                            Button("Delete Profile (For Testing)") {
                            authManager.deleteAccount()
                        }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            Button("Logout") {
                                authManager.signOut() // Assuming this method exists
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding() // Add padding to the main ScrollView's content VStack
            }
            .navigationTitle("Profile")
            .onAppear {
                fetchUserProfileFromCloudKit()
            }
        }
    }

    private func fetchUserProfileFromCloudKit() {
        isLoading = true
        errorMessage = nil

        guard let userRecordID = authManager.userRecordID else {
            errorMessage = "User record ID not found."
            isLoading = false
            return
        }

        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.fetch(withRecordID: userRecordID) { record, error in
            DispatchQueue.main.async {
                isLoading = false // Set isLoading to false in all paths within DispatchQueue.main.async
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                guard let record = record else {
                    errorMessage = "User profile not found."
                    return
                }

                name = record["name"] as? String ?? ""
                age = record["age"] as? Int ?? 0
                gender = record["gender"] as? String ?? ""
                cities = record["cities"] as? [String] ?? []
                let lowerBound = record["desiredAgeLowerBound"] as? Int ?? 18
                let upperBound = record["desiredAgeUpperBound"] as? Int ?? 99
                desiredAgeRange = lowerBound...upperBound
                desiredGenders = record["desiredGenders"] as? [String] ?? []

                if let photoAssets = record["photos"] as? [CKAsset] {
                    var loadedPhotos: [UIImage] = []
                    for asset in photoAssets {
                        if let fileURL = asset.fileURL {
                            do {
                                let data = try Data(contentsOf: fileURL)
                                if let image = UIImage(data: data) {
                                    loadedPhotos.append(image)
                                } else {
                                    print("Error: Could not create UIImage from data for asset: \(asset)")
                                }
                            } catch {
                                print("Error: Could not load data from fileURL for asset: \(asset), error: \(error)")
                            }
                        } else {
                            print("Error: fileURL is nil for asset: \(asset)")
                        }
                    }
                    self.photos = loadedPhotos
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
