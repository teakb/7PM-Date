import Combine
import AuthenticationServices // Import for ASAuthorization
import CloudKit // Import for CloudKit operations

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool? = nil // nil = unknown, true = signed in, false = not signed in
    @Published var isOnboardingComplete: Bool = false // New property to track onboarding status
    @Published var userRecordID: CKRecord.ID? // Store the user's CloudKit record ID

    private let container = CKContainer.default()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Attempt to get the current user's record ID on app launch
        // This implicitly checks if a user is already signed into CloudKit
        fetchUserRecordID()
    }

    func handleSignInWithAppleCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user // This is the unique ID for the user from Apple
                print("Sign in with Apple successful. User Identifier: \(userIdentifier)")

                // This is the correct way: Use the Apple userIdentifier for YOUR custom UserProfile record's ID
                let recordID = CKRecord.ID(recordName: userIdentifier)
                self.userRecordID = recordID // Store this for later use

                
                // Now, check if a user profile already exists for this recordID in CloudKit
                checkUserProfileExists(for: recordID) { exists in
                    DispatchQueue.main.async {
                        if exists {
                            self.isAuthenticated = true // User exists and is signed in
                            self.isOnboardingComplete = true // Mark onboarding complete for existing users
                            print("Existing user: Navigating to ContentView.")
                        } else {
                            self.isAuthenticated = true // User signed in, but new
                            self.isOnboardingComplete = false // User needs to complete onboarding
                            print("New user: Navigating to OnboardingStepsView.")
                        }
                    }
                }
            }
        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
            self.isAuthenticated = false // Sign-in failed
            self.isOnboardingComplete = false
        }
    }

    func fetchUserRecordID() {
        container.fetchUserRecordID { [weak self] (recordID, error) in
            DispatchQueue.main.async {
                if let recordID = recordID {
                    self?.userRecordID = recordID
                    // If we have a user record ID, check if their profile exists
                    self?.checkUserProfileExists(for: recordID) { exists in
                        DispatchQueue.main.async {
                            if exists {
                                self?.isAuthenticated = true
                                self?.isOnboardingComplete = true
                            } else {
                                self?.isAuthenticated = true // Signed in to iCloud, but profile not created yet
                                self?.isOnboardingComplete = false
                            }
                        }
                    }
                } else if let error = error as? CKError {
                    // Handle specific CloudKit errors for account status
                    if error.code == .notAuthenticated || error.code == .missingEntitlement {
                        print("User not authenticated with iCloud or missing CloudKit entitlement.")
                        self?.isAuthenticated = false
                        self?.isOnboardingComplete = false
                    } else {
                        print("Error fetching user record ID: \(error.localizedDescription)")
                        self?.isAuthenticated = nil // Unknown state on error
                        self?.isOnboardingComplete = false
                    }
                } else {
                    print("Could not determine user record ID, possibly not signed into iCloud.")
                    self?.isAuthenticated = false
                    self?.isOnboardingComplete = false
                }
            }
        }
    }

    // Checks if a 'UserProfile' record exists for the given userRecordID
    func checkUserProfileExists(for userRecordID: CKRecord.ID, completion: @escaping (Bool) -> Void) {
        let privateDatabase = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: userRecordID.recordName) // Use the same recordName for the profile
        
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let record = record, record.recordType == "UserProfile" {
                // Record exists and is of the correct type
                completion(true)
            } else if let ckError = error as? CKError, ckError.code == .unknownItem {
                // Record not found, meaning it's a new user
                completion(false)
            } else if let error = error {
                print("Error checking user profile existence: \(error.localizedDescription)")
                completion(false) // Treat errors as profile not existing for now, or handle specifically
            } else {
                completion(false) // No record or unexpected scenario
            }
        }
    }

    // Call this when the user decides to log out
    func signOut() {
        // For Sign In with Apple, there isn't a direct "logout" API.
        // You mostly manage the local session. To clear the local session:
        isAuthenticated = false
        isOnboardingComplete = false
        userRecordID = nil
        print("User signed out locally.")
        // If you had a custom backend, you'd also invalidate tokens there.
    }

    // Call this when the user wants to delete their account
    func deleteAccount() {
        guard let userRecordID = userRecordID else {
            print("No user record ID to delete.")
            return
        }

        let privateDatabase = container.privateCloudDatabase
        let recordIDToDelete = CKRecord.ID(recordName: userRecordID.recordName)

        privateDatabase.delete(withRecordID: recordIDToDelete) { (deletedRecordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error deleting user profile record: \(error.localizedDescription)")
                    // Handle specific errors like not found or permission issues
                } else if let deletedRecordID = deletedRecordID {
                    print("Successfully deleted user profile record: \(deletedRecordID.recordName)")
                    self.signOut() // Sign out locally after successful deletion
                }
            }
        }
        // You would also need to revoke the Sign In with Apple token if you have one.
        // This typically involves sending the authorizationCode to your server
        // and using Apple's API to revoke it. For client-side only, this is complex.
    }
}
