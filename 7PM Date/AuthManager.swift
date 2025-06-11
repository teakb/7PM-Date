import Combine
import AuthenticationServices
import CloudKit

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool? = nil // nil = checking status, true = authenticated, false = not authenticated
    @Published var isOnboardingComplete: Bool = false
    @Published var userRecordID: CKRecord.ID? // Stores the user's custom UserProfile record ID (derived from SIWA userIdentifier)

    private let container = CKContainer.default()
    private var cancellables = Set<AnyCancellable>()

    // Key for UserDefaults
    private let userIdentifierKey = "savedUserIdentifier"

    init() {
        // This is called automatically when AuthManager is initialized on app launch.
        checkInitialCloudKitStatus()
    }

    func checkInitialCloudKitStatus() {
        // 1. Try to load the persisted Apple userIdentifier first
        if let persistedUserIdentifier = UserDefaults.standard.string(forKey: userIdentifierKey) {
            let recordID = CKRecord.ID(recordName: persistedUserIdentifier)
            self.userRecordID = recordID // Set userRecordID from persisted ID

            print("Found persisted Apple User Identifier: \(persistedUserIdentifier)")

            // Now, check if the UserProfile exists for this persisted ID
            checkUserProfileExists(for: recordID) { [weak self] exists in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if exists {
                        self.isAuthenticated = true
                        self.isOnboardingComplete = true
                        print("Existing user: Persisted Apple ID found & profile complete. Navigating to ContentView.")
                    } else {
                        // Profile doesn't exist for this ID (e.g., deleted from dashboard, or onboarding not finished)
                        // In this case, the user needs to re-onboard or re-authenticate.
                        print("Persisted Apple ID found, but no profile. Forcing re-onboarding/re-auth.")
                        self.isAuthenticated = false
                        self.isOnboardingComplete = false
                        // Clean up persisted ID if profile doesn't exist for it
                        UserDefaults.standard.removeObject(forKey: self.userIdentifierKey)
                        self.userRecordID = nil
                    }
                }
            }
        } else {
            // 2. No persisted Apple userIdentifier found. Check iCloud account status.
            // This means it's a completely new launch or they explicitly signed out/deleted profile.
            print("No persisted Apple User Identifier found. Checking iCloud account status.")
            container.accountStatus { [weak self] (accountStatus, error) in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    switch accountStatus {
                    case .available:
                        // iCloud is available, but no SIWA ID is explicitly saved.
                        // This means the user needs to sign in via Apple again.
                        print("iCloud account available, but no persisted SIWA ID. Directing to SignIn.")
                        self.isAuthenticated = false
                        self.isOnboardingComplete = false
                    case .noAccount, .restricted, .couldNotDetermine:
                        print("iCloud account not available or restricted: \(accountStatus.rawValue)")
                        self.isAuthenticated = false
                        self.isOnboardingComplete = false
                    @unknown default:
                        print("Unknown iCloud account status: \(accountStatus.rawValue)")
                        self.isAuthenticated = false
                        self.isOnboardingComplete = false
                    }
                }
            }
        }
    }


    func handleSignInWithAppleCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user // Unique ID from Apple
                print("Sign in with Apple successful. User Identifier: \(userIdentifier)")

                // IMPORTANT: Persist the userIdentifier
                UserDefaults.standard.set(userIdentifier, forKey: userIdentifierKey)

                // Set userRecordID for immediate use
                let profileRecordID = CKRecord.ID(recordName: userIdentifier)
                self.userRecordID = profileRecordID

                // Check if a user profile record already exists for THIS userIdentifier in CloudKit
                self.checkUserProfileExists(for: profileRecordID) { exists in
                    DispatchQueue.main.async {
                        if exists {
                            self.isAuthenticated = true
                            self.isOnboardingComplete = true // Profile exists, onboarding complete
                            print("Existing user profile found for Apple ID. Navigating to ContentView.")
                        } else {
                            self.isAuthenticated = true // User is signed in via Apple
                            self.isOnboardingComplete = false // But needs to complete onboarding
                            print("New user (Apple ID). Navigating to OnboardingStepsView.")
                        }
                    }
                }
            }
        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
            self.isAuthenticated = false // Sign-in failed
            self.isOnboardingComplete = false // Can't onboard if not signed in
            UserDefaults.standard.removeObject(forKey: userIdentifierKey) // Clear any partial ID
            self.userRecordID = nil
        }
    }

    func checkUserProfileExists(for recordID: CKRecord.ID, completion: @escaping (Bool) -> Void) {
        let privateDatabase = container.privateCloudDatabase
        
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let record = record, record.recordType == "UserProfile" {
                completion(true)
            } else if let ckError = error as? CKError, ckError.code == .unknownItem {
                completion(false) // Record not found
            } else if let error = error {
                print("Error checking user profile existence: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(false)
            }
        }
    }

    func signOut() {
        // Clear local session state and persisted identifier
        isAuthenticated = false
        isOnboardingComplete = false
        userRecordID = nil
        UserDefaults.standard.removeObject(forKey: userIdentifierKey)
        print("User signed out locally and persisted identifier cleared.")
    }

    func deleteAccount() {
        guard let userRecordID = userRecordID else {
            print("No user profile ID to delete.")
            return
        }

        let privateDatabase = container.privateCloudDatabase
        
        let recordIDToDelete = userRecordID // userRecordID already holds the correct SIWA ID

        privateDatabase.delete(withRecordID: recordIDToDelete) { (deletedRecordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error deleting user profile record: \(error.localizedDescription)")
                    // If deletion fails, keep user logged in locally unless specific error occurs
                } else if let deletedRecordID = deletedRecordID {
                    print("Successfully deleted user profile record: \(deletedRecordID.recordName)")
                    self.signOut() // Sign out locally after successful deletion
                }
            }
        }
    }
}
