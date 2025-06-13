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
import PhotosUI

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
    @State private var isEditing: Bool = false
    @State private var showingImagePicker = false
    @State private var currentImageSelectionIndex: Int? = nil
    @State private var isSaving: Bool = false

    let genders = ["Male", "Female", "Non-binary", "Other"]
    let allCities = ["Oceanside", "Carlsbad", "Encinitas", "La Jolla", "Hillcrest"]

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
                        // Photo Gallery
                        photoGallerySection
                        
                        Divider().padding(.bottom, 10)

                        // Profile Details
                        if isEditing {
                            editProfileSection
                        } else {
                            viewProfileSection
                        }
                        
                        // Action Buttons
                        actionButtonsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isLoading {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveProfileToCloudKit()
                            } else {
                                isEditing = true
                            }
                        }
                        .disabled(isSaving)
                    }
                }
                if isEditing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isEditing = false
                            fetchUserProfileFromCloudKit() // Revert changes
                        }
                    }
                }
            }
            .onAppear {
                fetchUserProfileFromCloudKit()
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoPicker(selectedImage: Binding(
                    get: { self.currentImageSelectionIndex.map { self.photos[$0] } ?? nil },
                    set: { newImage in
                        if let index = self.currentImageSelectionIndex, let newImage = newImage {
                            self.photos[index] = newImage
                        }
                    }
                ))
            }
        }
    }

    private var photoGallerySection: some View {
        Group {
            if !photos.isEmpty {
                TabView {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, uiImage in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture {
                                if isEditing {
                                    currentImageSelectionIndex = index
                                    showingImagePicker = true
                                }
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 300)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.bottom)
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundColor(Color(UIColor.systemGray2))
                    Text("No photos available.")
                        .font(.headline)
                        .foregroundColor(Color(UIColor.systemGray))
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.bottom)
                .onTapGesture {
                    if isEditing {
                        currentImageSelectionIndex = photos.count < 3 ? photos.count : nil
                        if currentImageSelectionIndex != nil {
                            showingImagePicker = true
                        }
                    }
                }
            }
        }
    }

    private var viewProfileSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 5)

            HStack {
                Text("Age: \(age)")
                Spacer()
                Text("Gender: \(gender)")
            }
            .font(.title3)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 3) {
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
        .padding(.bottom, 20)
    }

    private var editProfileSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Stepper("Age: \(age)", value: $age, in: 18...99)

            Picker("Gender", selection: $gender) {
                ForEach(genders, id: \.self) { g in
                    Text(g)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Text("Interested in cities:")
                .font(.headline)
            MultiSelectPicker(items: allCities, selectedItems: $cities)

            Text("Looking for ages:")
                .font(.headline)
            RangeSlider(range: $desiredAgeRange, in: 18...99)

            Text("Interested in genders:")
                .font(.headline)
            MultiSelectPicker(items: genders, selectedItems: $desiredGenders)
        }
        .padding(.bottom, 20)
    }

    private var actionButtonsSection: some View {
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
                authManager.signOut()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
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
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let record = record else {
                    self.errorMessage = "User profile not found."
                    return
                }

                self.name = record["name"] as? String ?? ""
                self.age = record["age"] as? Int ?? 0
                self.gender = record["gender"] as? String ?? ""
                self.cities = record["cities"] as? [String] ?? []
                let lowerBound = record["desiredAgeLowerBound"] as? Int ?? 18
                let upperBound = record["desiredAgeUpperBound"] as? Int ?? 99
                self.desiredAgeRange = lowerBound...upperBound
                self.desiredGenders = record["desiredGenders"] as? [String] ?? []

                self.photos = []
                if let photoAssets = record["photos"] as? [CKAsset] {
                    for asset in photoAssets {
                        if let fileURL = asset.fileURL, let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                            self.photos.append(image)
                        }
                    }
                }
            }
        }
    }

    private func saveProfileToCloudKit() {
        isSaving = true
        guard let userRecordID = authManager.userRecordID else {
            errorMessage = "User record ID not found."
            isSaving = false
            return
        }

        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.fetch(withRecordID: userRecordID) { record, error in
            guard let record = record, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch profile for update."
                    self.isSaving = false
                }
                return
            }

            record["name"] = self.name
            record["age"] = self.age
            record["gender"] = self.gender
            record["cities"] = self.cities
            record["desiredAgeLowerBound"] = self.desiredAgeRange.lowerBound
            record["desiredAgeUpperBound"] = self.desiredAgeRange.upperBound
            record["desiredGenders"] = self.desiredGenders

            // Handle photos
            var photoAssets: [CKAsset] = []
            for (index, photo) in self.photos.enumerated() {
                if let asset = createCKAsset(from: photo, fileName: "profile_photo_\(index).jpg") {
                    photoAssets.append(asset)
                }
            }
            record["photos"] = photoAssets

            privateDatabase.save(record) { savedRecord, saveError in
                DispatchQueue.main.async {
                    self.isSaving = false
                    if let saveError = saveError {
                        self.errorMessage = "Failed to save profile: \(saveError.localizedDescription)"
                    } else {
                        self.isEditing = false
                        self.fetchUserProfileFromCloudKit() // Refresh UI
                    }
                }
            }
        }
    }

    private func createCKAsset(from image: UIImage, fileName: String) -> CKAsset? {
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }
}

struct MultiSelectPicker: View {
    let items: [String]
    @Binding var selectedItems: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        if selectedItems.contains(item) {
                            selectedItems.removeAll { $0 == item }
                        } else {
                            selectedItems.append(item)
                        }
                    }) {
                        Text(item)
                            .padding(8)
                            .background(selectedItems.contains(item) ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedItems.contains(item) ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}



#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
