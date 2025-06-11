import SwiftUI
import CloudKit // Import CloudKit for saving data
import PhotosUI // For modern image picker (iOS 14+)

// This is the complete and updated OnboardingStepsView.swift file.
// It includes fixes for the previous compilation errors, UI responsiveness,
// and robust CloudKit saving logic.

struct OnboardingStepsView: View {
    @EnvironmentObject var authManager: AuthManager // Access AuthManager
    
    // MARK: - State Variables for Onboarding Data
    @State private var name: String = ""
    @State private var age: Int = 21
    @State private var gender: String = "Male" // Default to avoid empty initial state
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

    // MARK: - Main View Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tell Us About Yourself")
                    .font(.largeTitle)
                    .bold()
                
                // Name Input
                Group {
                    Text("Your Name").font(.headline)
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name) // Semantic type for autofill
                }

                // Age Input
                Group {
                    Text("Your Age").font(.headline)
                    TextField("Age", value: $age, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Gender Picker
                Group {
                    Text("Your Gender").font(.headline)
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.self) { gender in
                            Text(gender).tag(gender) // Ensure tag is set for Picker
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.blue) // Apply tint to make picker visible and tappable
                }

                // Cities Selection (using custom FlowLayout for better wrapping)
                Group {
                    Text("Select up to 5 cities you're interested in:").font(.headline)
                    FlowLayout(alignment: .leading, spacing: 8) {
                        ForEach(cities, id: \.self) { city in
                            Button(action: {
                                if selectedCities.contains(city) {
                                    selectedCities.remove(city)
                                } else if selectedCities.count < 5 { // Limit to 5 cities
                                    selectedCities.insert(city)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedCities.contains(city) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.blue)
                                    Text(city)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedCities.contains(city) ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Photo Upload Section
                Group {
                    Text("Upload 3 photos:").font(.headline)
                    HStack {
                        ForEach(0..<3) { idx in
                            ZStack {
                                if let img = images[idx] {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Rectangle()
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                        .frame(width: 100, height: 100)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                        .overlay(Image(systemName: "plus").font(.largeTitle).foregroundColor(.gray))
                                }
                            }
                            .onTapGesture {
                                currentImageSelectionIndex = idx
                                showingImagePicker = true
                            }
                        }
                    }
                }

                // Desired Age Range Slider
                Group {
                    Text("Desired age range:").font(.headline)
                    RangeSlider(range: $desiredAgeRange, in: 18...60)
                    Text("From \(desiredAgeRange.lowerBound) to \(desiredAgeRange.upperBound) years old")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Desired Genders Selection
                Group {
                    Text("Interested in:").font(.headline)
                    FlowLayout(alignment: .leading, spacing: 8) {
                        ForEach(genders, id: \.self) { gender in
                            Button(action: {
                                if desiredGenders.contains(gender) {
                                    desiredGenders.remove(gender)
                                } else {
                                    desiredGenders.insert(gender)
                                }
                            }) {
                                HStack {
                                    Image(systemName: desiredGenders.contains(gender) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.blue)
                                    Text(gender)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(desiredGenders.contains(gender) ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Submit Button
                Button {
                    isSaving = true // Indicate saving process has started
                    saveUserProfileToCloudKit()
                } label: {
                    if isSaving {
                        ProgressView() // Show a loading indicator
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Complete Onboarding")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(formIsComplete && !isSaving ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!formIsComplete || isSaving) // Disable if form not complete OR saving
                .padding(.top, 20)
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
        !name.isEmpty && age >= 18 && !gender.isEmpty && !selectedCities.isEmpty && images.allSatisfy { $0 != nil } && !desiredGenders.isEmpty
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

    // Helper to convert UIImage to CKAsset (by saving to temp file)
    func createCKAsset(from image: UIImage, fileName: String) -> CKAsset? {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to get JPEG data from image.")
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return CKAsset(fileURL: url)
        } catch {
            print("Error creating CKAsset from image: \(error.localizedDescription)")
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

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
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
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            self?.parent.selectedImage = image
                        } else {
                            print("Error loading image from PHPicker: \(error?.localizedDescription ?? "unknown")")
                        }
                    }
                }
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
