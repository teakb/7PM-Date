import SwiftUI
import CloudKit // Import CloudKit for saving data

struct OnboardingStepsView: View {
    @EnvironmentObject var authManager: AuthManager // Access AuthManager
    @State private var name: String = ""
    @State private var age: Int = 21
    @State private var gender: String = "Male" // Default to avoid empty initial state
    @State private var selectedCities: Set<String> = []
    @State private var images: [UIImage?] = [nil, nil, nil]
    @State private var desiredAgeRange: ClosedRange<Int> = 21...30
    @State private var desiredGenders: Set<String> = []
    @State private var showingImagePicker = false
    @State private var currentImageSelectionIndex: Int? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""

    let cities = ["Oceanside", "Carlsbad", "Encinitas", "La Jolla", "Hillcrest"]
    let genders = ["Male", "Female", "Non-binary", "Other"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tell Us About Yourself").font(.largeTitle).bold()
                
                Group {
                    Text("Your Name").font(.headline)
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                Group {
                    Text("Your Age").font(.headline)
                    TextField("Age", value: $age, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
                
                Group {
                    Text("Your Gender").font(.headline)
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.self) { gender in
                            Text(gender).tag(gender) // Ensure tag is set for Picker
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.blue) // Apply tint to make picker visible
                }

                Group {
                    Text("Select up to 5 cities you're interested in:").font(.headline)
                    FlowLayout(alignment: .leading) { // Using a custom FlowLayout for better city display
                        ForEach(cities, id: \.self) { city in
                            Button(action: {
                                if selectedCities.contains(city) {
                                    selectedCities.remove(city)
                                } else if selectedCities.count < 5 {
                                    selectedCities.insert(city)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedCities.contains(city) ? "checkmark.square.fill" : "square")
                                    Text(city)
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

                Group {
                    Text("Desired age range:").font(.headline)
                    RangeSlider(range: $desiredAgeRange, in: 18...60)
                    Text("From \(desiredAgeRange.lowerBound) to \(desiredAgeRange.upperBound) years old")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Group {
                    Text("Interested in:").font(.headline)
                    FlowLayout(alignment: .leading) {
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
                                    Text(gender)
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

                Button("Complete Onboarding") {
                    saveUserProfileToCloudKit()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(formIsComplete ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!formIsComplete)
                .padding(.top, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: { self.currentImageSelectionIndex.map { self.images[$0] } ?? nil },
                set: { newImage in
                    if let index = self.currentImageSelectionIndex {
                        self.images[index] = newImage
                    }
                }
            ))
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    var formIsComplete: Bool {
        !name.isEmpty && age >= 18 && !gender.isEmpty && !selectedCities.isEmpty && images.allSatisfy { $0 != nil } && !desiredGenders.isEmpty
    }

    func saveUserProfileToCloudKit() {
        guard let userRecordID = authManager.userRecordID else {
            alertMessage = "User not authenticated for CloudKit."
            showingAlert = true
            return
        }

        let privateDatabase = CKContainer.default().privateCloudDatabase
        let userProfileRecord = CKRecord(recordType: "UserProfile", recordID: userRecordID)

        userProfileRecord["name"] = name
        userProfileRecord["age"] = age as CKRecordValue
        userProfileRecord["gender"] = gender
        userProfileRecord["cities"] = Array(selectedCities) as CKRecordValue
        userProfileRecord["desiredAgeLowerBound"] = desiredAgeRange.lowerBound as CKRecordValue
        userProfileRecord["desiredAgeUpperBound"] = desiredAgeRange.upperBound as CKRecordValue
        userProfileRecord["desiredGenders"] = Array(desiredGenders) as CKRecordValue
        
        // Handle images (CKAsset)
        var photoAssets: [CKAsset] = []
        for (index, image) in images.enumerated() {
            if let image = image, let asset = createCKAsset(from: image, fileName: "user_photo_\(index).jpg") {
                photoAssets.append(asset)
            }
        }
        userProfileRecord["photos"] = photoAssets as CKRecordValue

        privateDatabase.save(userProfileRecord) { (record, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error saving user profile to CloudKit: \(error.localizedDescription)")
                    self.alertMessage = "Failed to save profile: \(error.localizedDescription)"
                    self.showingAlert = true
                } else if let _ = record {
                    print("User profile saved successfully to CloudKit!")
                    // Mark onboarding complete in AuthManager
                    self.authManager.isOnboardingComplete = true
                    // You might also want to set isAuthenticated = true again here
                    // to trigger the navigation to ContentView if it wasn't already true.
                    self.authManager.isAuthenticated = true
                }
            }
        }
    }

    // Helper to convert UIImage to CKAsset (by saving to temp file)
    func createCKAsset(from image: UIImage, fileName: String) -> CKAsset? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
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

// Placeholder for range slider (implement as needed or use open-source)
// Placeholder for range slider (implement as needed or use open-source)
struct RangeSlider: View {
    @Binding var range: ClosedRange<Int>
    let `in`: ClosedRange<Int> // Corrected: removed the extra '`' and added the closing '>'
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
// Helper for image picking (standard UIKit integration)
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

// MARK: - FlowLayout for dynamic item arrangement (Optional, but improves layout)
// MARK: - FlowLayout for dynamic item arrangement (Optional, but improves layout)
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
            // Corrected: Use .infinity for proposed size dimensions
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: .infinity, height: .infinity))
            if currentX + subviewSize.width + spacing > containerWidth && currentX > 0 {
                // New line
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
            // Corrected: Use .infinity for proposed size dimensions
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: .infinity, height: .infinity))
            if currentX + subviewSize.width + spacing > containerWidth && currentX > bounds.minX {
                // Place items on the current line then start a new one
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
        // Place any remaining items on the last line
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
        default: // Fallback for other alignments or new ones
            startX = bounds.minX
        }

        var currentX = startX
        for (subview, size) in items {
            subview.place(at: CGPoint(x: currentX, y: y), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
        }
    }
}
