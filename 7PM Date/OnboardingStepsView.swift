import SwiftUI
import CloudKit // Import CloudKit for saving data
import PhotosUI // For modern image picker (iOS 14+)

// This is the complete and updated OnboardingStepsView.swift file.
// It includes the new home city selection, fixes for the previous compilation errors,
// UI responsiveness, and robust CloudKit saving logic.

struct OnboardingStepsView: View {
    @EnvironmentObject var authManager: AuthManager // Access AuthManager
    
    // MARK: - State Variables for Onboarding Data
    @State private var name: String = ""
    @State private var age: Int = 21
    @State private var gender: String = "Male" // Default to avoid empty initial state
    @State private var homeCity: String = "" // NEW: For user's home city
    @State private var selectedCities: Set<String> = []
    @State private var images: [UIImage?] = [nil, nil, nil] // Array to hold 3 selected images
    @State private var desiredAgeRange: ClosedRange<Int> = 21...30
    @State private var desiredGenders: Set<String> = []

    // MARK: - UI State Variables
    @State private var showingImagePicker = false
    @State private var currentImageSelectionIndex: Int? = nil // To know which image slot is being filled
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false // Prevents multiple taps and provides visual feedback

    // MARK: - Static Data for Pickers/Lists
    let cities = ["Oceanside", "Carlsbad", "Encinitas", "La Jolla", "Hillcrest"]
    let genders = ["Male", "Female", "Non-binary", "Other"]

    // MARK: - Sections
    private var profileBasicsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Profile Basics")
                .font(.title2).bold()
                .padding(.bottom, 5)
            
            // Name Input
            VStack(alignment: .leading) {
                Text("Your Name").font(.headline)
                TextField("Name", text: $name)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .textContentType(.name)
            }
            .padding(.bottom, 10)

            // Age Input
            VStack(alignment: .leading) {
                Text("Your Age").font(.headline)
                TextField("Age", value: $age, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 100) // Adjusted frame for padding
            }
            .padding(.bottom, 10)
            
            // Gender Picker
            VStack(alignment: .leading) {
                Text("Your Gender").font(.headline)
                Picker("Gender", selection: $gender) {
                    ForEach(genders, id: \.self) { genderItem in // Renamed to avoid conflict
                        Text(genderItem).tag(genderItem)
                    }
                }
                .pickerStyle(.menu)
                .tint(.blue)
            }
        }
        .padding() // Padding for the whole section
        .background(Color(UIColor.secondarySystemGroupedBackground)) // Optional: card-like bg
        .cornerRadius(12) // Optional: card-like bg
        .padding(.bottom) // Space between sections
    }

    // NEW: Section for selecting the user's home city
    private var homeCitySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Home City")
                .font(.title2).bold()
                .padding(.bottom, 5)

            Text("Select the city you are from:").font(.subheadline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(cities, id: \.self) { city in
                    Button(action: {
                        // This enforces a single selection
                        homeCity = city
                    }) {
                        Text(city)
                            .font(.system(size: 14, weight: .medium))
                            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .foregroundColor(homeCity == city ? .white : .primary)
                            .background(homeCity == city ? Color.blue : Color(UIColor.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.bottom)
    }

    private var locationPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Location Preferences")
                .font(.title2).bold()
                .padding(.bottom, 5)
            
            Text("Select up to 5 cities you're interested in:").font(.subheadline) // Changed from .headline
            VStack(alignment: .leading, spacing: 8) { // Replaced FlowLayout with VStack
                ForEach(cities, id: \.self) { city in
                    Button(action: {
                        if selectedCities.contains(city) {
                            selectedCities.remove(city)
                        } else if selectedCities.count < 5 {
                            selectedCities.insert(city)
                        }
                    }) {
                        Text(city)
                            .font(.system(size: 14, weight: .medium))
                            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .foregroundColor(selectedCities.contains(city) ? .white : .primary)
                            .background(selectedCities.contains(city) ? Color.blue : Color(UIColor.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.bottom)
    }

    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Upload Your Photos")
                .font(.title2).bold()
                .padding(.bottom, 5)

            Text("Upload 3 photos:").font(.subheadline)
            HStack(spacing: 15) {
                ForEach(0..<3) { idx in
                    VStack { // Wrap ZStack and Text in a VStack
                        ZStack {
                            if let img = images[idx] {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10)) // Consistent corner radius
                            } else {
                                RoundedRectangle(cornerRadius: 10) // Consistent corner radius
                                    .fill(Color(UIColor.systemGray6))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.largeTitle)
                                            .foregroundColor(Color(UIColor.systemGray2))
                                    )
                            }
                        }
                        .onTapGesture {
                            currentImageSelectionIndex = idx
                            showingImagePicker = true
                        }
                        Text("Photo \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.bottom)
    }

    private var datingPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Dating Preferences")
                .font(.title2).bold()
                .padding(.bottom, 5)

            // Desired Age Range Slider
            VStack(alignment: .leading) {
                Text("Desired age range:").font(.subheadline) // Changed from .headline
                RangeSlider(range: $desiredAgeRange, in: 18...60)
                Text("From \(desiredAgeRange.lowerBound) to \(desiredAgeRange.upperBound) years old")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center) // Center the caption
            }
            .padding(.bottom, 10)
            
            // Desired Genders Selection
            VStack(alignment: .leading) {
                Text("Interested in:").font(.subheadline) // Changed from .headline
                VStack(alignment: .leading, spacing: 8) { // Replaced FlowLayout with VStack
                    ForEach(genders, id: \.self) { genderItem in // Renamed to avoid conflict
                        Button(action: {
                            if desiredGenders.contains(genderItem) {
                                desiredGenders.remove(genderItem)
                            } else {
                                desiredGenders.insert(genderItem)
                            }
                        }) {
                            Text(genderItem)
                                .font(.system(size: 14, weight: .medium))
                                .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .foregroundColor(desiredGenders.contains(genderItem) ? .white : .primary)
                                .background(desiredGenders.contains(genderItem) ? Color.blue : Color(UIColor.systemGray5))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.bottom)
    }

    private var submitButtonSection: some View {
        Button {
            isSaving = true // Indicate saving process has started
            saveUserProfileToCloudKit()
        } label: {
            if isSaving {
                ProgressView() // Show a loading indicator
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Complete Onboarding")
                    .fontWeight(.semibold) // Added font weight
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(formIsComplete && !isSaving ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .clipShape(Capsule()) // Changed cornerRadius to Capsule
        .disabled(!formIsComplete || isSaving)
        .padding(.top, 20)
    }

    // MARK: - Main View Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { // Increased main spacing
                Text("Create Your Profile") // Updated overall title
                    .font(.largeTitle).bold()
                    .padding(.bottom)

                profileBasicsSection
                homeCitySection // NEW: Added home city section
                locationPreferencesSection
                photoUploadSection
                datingPreferencesSection
                submitButtonSection
            }
            .padding()
        }
        // Image Picker Presentation (Conditionally use PHPickerViewController)
        .sheet(isPresented: $showingImagePicker) {
            if #available(iOS 14, *) {
                PhotoPicker(selectedImage: Binding(
                    get: { self.currentImageSelectionIndex.map { self.images[$0] } ?? nil },
                    set: { newImage in
                        if let index = self.currentImageSelectionIndex {
                            self.images[index] = newImage
                        }
                    }
                ))
            } else {
                ImagePicker(selectedImage: Binding(
                    get: { self.currentImageSelectionIndex.map { self.images[$0] } ?? nil },
                    set: { newImage in
                        if let index = self.currentImageSelectionIndex {
                            self.images[index] = newImage
                        }
                    }
                ))
            }
        }
        // Alert for errors
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        // Ensure minimum age for form completion (optional, but good practice)
        .onChange(of: age) { newAge in
            if newAge < 18 {
                alertMessage = "You must be at least 18 years old to use this app."
                showingAlert = true
                age = 18 // Reset to minimum if invalid
            }
        }
    }

    // MARK: - Computed Property for Form Validation
    var formIsComplete: Bool {
        !name.isEmpty && age >= 18 && !gender.isEmpty && !homeCity.isEmpty && !selectedCities.isEmpty && images.allSatisfy { $0 != nil } && !desiredGenders.isEmpty
    }

    // MARK: - CloudKit Saving Function
    func saveUserProfileToCloudKit() {
        guard let userRecordID = authManager.userRecordID else {
            alertMessage = "User not authenticated for CloudKit. Please try signing in again."
            showingAlert = true
            isSaving = false // Reset saving state
            return
        }

        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        // Create a new CKRecord with our custom UserProfile record type and the user's unique Apple ID
        let userProfileRecord = CKRecord(recordType: "UserProfile", recordID: userRecordID)

        // Assign all profile data to the record fields
        userProfileRecord["name"] = name as CKRecordValue
        userProfileRecord["age"] = age as CKRecordValue
        userProfileRecord["gender"] = gender as CKRecordValue
        userProfileRecord["homeCity"] = homeCity as CKRecordValue // NEW: Save home city
        userProfileRecord["cities"] = Array(selectedCities) as CKRecordValue // CloudKit supports String List
        userProfileRecord["desiredAgeLowerBound"] = desiredAgeRange.lowerBound as CKRecordValue
        userProfileRecord["desiredAgeUpperBound"] = desiredAgeRange.upperBound as CKRecordValue
        userProfileRecord["desiredGenders"] = Array(desiredGenders) as CKRecordValue // CloudKit supports String List
        
        // --- DIAGNOSTIC PRINTS ---
        print("\n--- Attempting to save CKRecord ---")
        print("Record Type: \(userProfileRecord.recordType)")
        print("Record ID: \(userProfileRecord.recordID.recordName)")
        print("Name: \(userProfileRecord["name"] as? String ?? "N/A")")
        print("Age: \(userProfileRecord["age"] as? Int ?? -1)")
        print("Gender: \(userProfileRecord["gender"] as? String ?? "N/A")")
        print("Home City: \(userProfileRecord["homeCity"] as? String ?? "N/A")") // NEW: Print home city
        print("Cities: \(userProfileRecord["cities"] as? [String] ?? [])")
        print("Desired Age Lower Bound: \(userProfileRecord["desiredAgeLowerBound"] as? Int ?? -1)")
        print("Desired Age Upper Bound: \(userProfileRecord["desiredAgeUpperBound"] as? Int ?? -1)")
        print("Desired Genders: \(userProfileRecord["desiredGenders"] as? [String] ?? [])")
        print("Number of Photo Assets: \(images.compactMap { $0 }.count)") // Use original images count for print
        print("-----------------------------------\n")

        // Use a DispatchGroup to wait for all assets to be created before saving
        let group = DispatchGroup()
        var tempPhotoAssets: [CKAsset] = []
        var creationErrors: [Error] = []

        for (index, image) in images.enumerated() {
            if let image = image {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async { // Perform on background queue
                    if let asset = createCKAsset(from: image, fileName: "user_photo_\(index)_\(userRecordID.recordName).jpg") {
                        tempPhotoAssets.append(asset)
                    } else {
                        creationErrors.append(NSError(domain: "ImageConversionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image \(index)"]))
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { // Back to main queue when all assets are ready
            if !creationErrors.isEmpty {
                self.alertMessage = "Failed to process some images: \(creationErrors.first!.localizedDescription)"
                self.showingAlert = true
                self.isSaving = false
                return // Don't proceed with save if image conversion failed
            }
            
            // Assign the created CKAssets to the record
            userProfileRecord["photos"] = tempPhotoAssets as CKRecordValue

            // Save the record to CloudKit
            privateDatabase.save(userProfileRecord) { (record, error) in
                DispatchQueue.main.async { // Ensure UI updates and state changes happen on the main thread
                    self.isSaving = false // Reset saving state after completion (success or failure)
                    if let error = error {
                        if let ckError = error as? CKError {
                            print("CloudKit save error code: \(ckError.code.rawValue) - \(ckError.localizedDescription)")
                            if ckError.code == .serverRecordChanged || ckError.code == .serverRejectedRequest {
                                self.alertMessage = "Profile already exists or conflict detected. Attempting to update instead."
                                // Try to fetch and update the existing record
                                self.updateUserProfileInCloudKit(recordID: userRecordID, with: userProfileRecord)
                                return // Exit this block, update is handled by the new function
                            }
                            
                            // Using rawValue for compatibility with older deployment targets
                            // Common CKError codes:
                            // .networkUnavailable (1), .networkFailure (2), .partialFailure (10), .zoneNotFound (13),
                            // .unknownItem (11), .notAuthenticated (9), .quotaExceeded (23), .assetFileNotAvailable (36)
                            // We check the rawValue as the enum members might not exist directly.
                            if ckError.code.rawValue == 23 { // CKError.Code.quotaExceeded
                                self.alertMessage = "iCloud storage quota exceeded. Please clear space or upgrade."
                            } else if ckError.code.rawValue == 36 { // CKError.Code.assetFileNotAvailable (iOS 17+)
                                self.alertMessage = "One or more photo files could not be found. Please try re-uploading."
                            } else {
                                self.alertMessage = "Failed to save profile: \(error.localizedDescription)"
                            }
                        } else {
                            self.alertMessage = "Failed to save profile: \(error.localizedDescription)"
                        }
                        self.showingAlert = true
                    } else if let _ = record {
                        print("User profile saved successfully to CloudKit!")
                        self.authManager.isOnboardingComplete = true
                        self.authManager.isAuthenticated = true
                    }
                }
            }
        }
    }

    // NEW: Function to update an existing user profile
    func updateUserProfileInCloudKit(recordID: CKRecord.ID, with newRecordData: CKRecord) {
        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        privateDatabase.fetch(withRecordID: recordID) { (existingRecord, error) in
            DispatchQueue.main.async {
                if let existingRecord = existingRecord {
                    // Update the fields of the existing record with new values
                    existingRecord["name"] = newRecordData["name"]
                    existingRecord["age"] = newRecordData["age"]
                    existingRecord["gender"] = newRecordData["gender"]
                    existingRecord["homeCity"] = newRecordData["homeCity"] // NEW: Update home city
                    existingRecord["cities"] = newRecordData["cities"]
                    existingRecord["desiredAgeLowerBound"] = newRecordData["desiredAgeLowerBound"]
                    existingRecord["desiredAgeUpperBound"] = newRecordData["desiredAgeUpperBound"]
                    existingRecord["desiredGenders"] = newRecordData["desiredGenders"]
                    existingRecord["photos"] = newRecordData["photos"] // Overwrite photos if needed

                    privateDatabase.save(existingRecord) { (record, error) in
                        DispatchQueue.main.async {
                            self.isSaving = false
                            if let error = error {
                                print("Error updating user profile in CloudKit: \(error.localizedDescription)")
                                self.alertMessage = "Failed to update profile: \(error.localizedDescription)"
                                self.showingAlert = true
                            } else if let _ = record {
                                print("User profile updated successfully in CloudKit!")
                                self.authManager.isOnboardingComplete = true
                                self.authManager.isAuthenticated = true
                            }
                        }
                    }
                } else if let ckError = error as? CKError, ckError.code == .unknownItem {
                    print("Record to update not found (CKError.unknownItem), this is unexpected if called after 'record exists'. Attempting re-save as new: \(error?.localizedDescription ?? "")")
                    // This scenario means the record might have been deleted right before the update attempt.
                    // Recurse to try saving as a new record again.
                    self.saveUserProfileToCloudKit()
                } else {
                    print("Error fetching record for update: \(error?.localizedDescription ?? "")")
                    self.alertMessage = "Failed to fetch profile for update: \(error?.localizedDescription ?? "")"
                    self.showingAlert = true
                }
            }
        }
    }

    // Helper function to resize UIImage (can be nested or outside)
    func resizeImage(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        // Don't scale up if the image is already smaller than maxDimension
        if scale >= 1.0 { return image }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Using UIGraphicsImageRenderer for modern, efficient rendering
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }

    // Modified createCKAsset function
    func createCKAsset(from image: UIImage, fileName: String) -> CKAsset? {
        // Resize the image first
        let resizedImage = resizeImage(image: image, maxDimension: 1920) // Max dimension of 1920px

        guard let data = resizedImage.jpegData(compressionQuality: 0.75) else { // Adjusted compression if needed
            print("Failed to get JPEG data from resized image.")
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return CKAsset(fileURL: url)
        } catch {
            print("Error creating CKAsset from resized image: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - RangeSlider View
struct RangeSlider: View {
    @Binding var range: ClosedRange<Int>
    let `in`: ClosedRange<Int>
    var body: some View {
        HStack {
            Text("\(range.lowerBound)")
            Slider(value: Binding(get: { Double(range.lowerBound) }, set: { val in
                let clampedLower = max(Int(val), `in`.lowerBound)
                range = clampedLower...max(clampedLower, range.upperBound)
            }), in: Double(`in`.lowerBound)...Double(`in`.upperBound), step: 1)
            Text("-\(range.upperBound)")
            Slider(value: Binding(get: { Double(range.upperBound) }, set: { val in
                let clampedUpper = min(Int(val), `in`.upperBound)
                range = min(range.lowerBound, clampedUpper)...clampedUpper
            }), in: Double(`in`.lowerBound)...Double(`in`.upperBound), step: 1)
        }
    }
}

// MARK: - ImagePicker View (using UIImagePickerController for simplicity)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // Inside ImagePicker.Coordinator
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Move image processing to a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                var finalImage: UIImage? = nil
                if let image = info[.originalImage] as? UIImage {
                    // If further processing like resizing or format conversion was needed,
                    // it would happen here on this background thread.
                    finalImage = image
                }

                // Switch back to the main thread to update the UI and dismiss the picker
                DispatchQueue.main.async {
                    self.parent.selectedImage = finalImage
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
            // Note: Dismissal is now also on the main thread after image processing.
            // If image processing is quick, this is fine. If it could be long,
            // consider dismissing earlier on the main thread right after picker.dismiss if UI feels unresponsive.
            // However, the original code dismissed after setting the image.
        }
    
        // Ensure imagePickerControllerDidCancel is also robust
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async { // Ensure dismissal is on main thread
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - PhotoPicker (iOS 14+) using PHPickerViewController
@available(iOS 14, *)
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }

            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                // Start progress indication if possible/desired (outside this immediate scope)
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    // Perform image processing on a background thread
                    DispatchQueue.global(qos: .userInitiated).async {
                        var finalImage: UIImage? = nil
                        if let image = object as? UIImage {
                            // If further processing like resizing or format conversion was needed,
                            // it would happen here on this background thread.
                            // For now, we just ensure UIImage creation is backgrounded.
                            finalImage = image
                        } else if let error = error {
                            print("Error loading image from PHPicker: \(error.localizedDescription)")
                        }

                        // Switch back to the main thread to update the UI
                        DispatchQueue.main.async {
                            self?.parent.selectedImage = finalImage
                            // Stop progress indication if started
                        }
                    }
                }
            } else if let error = results.first?.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { _, e in e } ) as? Error { // A bit of a hack to get an error if canLoadObject is false
                print("Error: Cannot load UIImage from selected item. Error: \(error.localizedDescription)")
            }
        }
    }
}


// MARK: - FlowLayout for dynamic item arrangement
struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: .infinity, height: .infinity))
            if currentX + subviewSize.width + spacing > containerWidth && currentX > 0 {
                totalHeight += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            currentX += subviewSize.width + spacing
            lineHeight = max(lineHeight, subviewSize.height)
        }
        totalHeight += lineHeight
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let containerWidth = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        var lineItems: [(subview: LayoutSubviews.Element, size: CGSize)] = []

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: .infinity, height: .infinity))
            if currentX + subviewSize.width + spacing > containerWidth && currentX > bounds.minX {
                placeLineItems(lineItems, atY: currentY, in: bounds, containerWidth: containerWidth)
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
                lineItems.removeAll()
            }
            lineItems.append((subview, subviewSize))
            currentX += subviewSize.width + spacing
            lineHeight = max(lineHeight, subviewSize.height)
        }
        placeLineItems(lineItems, atY: currentY, in: bounds, containerWidth: containerWidth)
    }
    
    private func placeLineItems(_ items: [(subview: LayoutSubviews.Element, size: CGSize)], atY y: CGFloat, in bounds: CGRect, containerWidth: CGFloat) {
        let totalWidth = items.reduce(0) { $0 + $1.size.width } + CGFloat(items.count - 1) * spacing
        var startX: CGFloat

        switch alignment {
        case .leading:
            startX = bounds.minX
        case .center:
            startX = bounds.minX + (containerWidth - totalWidth) / 2
        case .trailing:
            startX = bounds.maxX - totalWidth
        default:
            startX = bounds.minX
        }

        var currentX = startX
        for (subview, size) in items {
            subview.place(at: CGPoint(x: currentX, y: y), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
        }
    }
}

#Preview {
    OnboardingStepsView().environmentObject(AuthManager())
}
