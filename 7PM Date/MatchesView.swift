//
//  MatchesView.swift
//  7PM Date
//
//  Created by AI Assistant on 2025-06-12
//

import SwiftUI
import CloudKit

struct MatchesView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var connections: [MatchInfo] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading your connections...")
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                } else if connections.isEmpty {
                    Text("No mutual connections yet. Keep dating!")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(connections) { match in
                            HStack {
                                // Basic display: Photo (placeholder if none), Name, Age
                                if let firstPhotoAsset = match.photos.first {
                                    CloudKitImageView(asset: firstPhotoAsset) // Reusing CloudKitImageView from SpeedDatingView
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray)
                                }
                                VStack(alignment: .leading) {
                                    Text(match.name).font(.headline)
                                    Text("\(match.age) years old").font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Connections")
            .onAppear {
                fetchConnections()
            }
        }
    }

    private func fetchConnections() {
        isLoading = true
        errorMessage = nil
        connections = [] // Clear previous connections

        guard let currentUserRecordID = authManager.userRecordID else {
            errorMessage = "User not authenticated."
            isLoading = false
            return
        }

        let publicDatabase = CKContainer.default().publicCloudDatabase
        // Step A: Fetch current user's positive decisions
        let currentUserPredicate = NSPredicate(format: "decidingUserRef == %@ AND didConnect == TRUE", CKRecord.Reference(recordID: currentUserRecordID, action: .none))
        let currentUserQuery = CKQuery(recordType: "MatchDecision", predicate: currentUserPredicate)

        publicDatabase.perform(currentUserQuery, inZoneWith: nil) { myDecisionRecords, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching your decisions: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            guard let myDecisions = myDecisionRecords, !myDecisions.isEmpty else {
                DispatchQueue.main.async {
                    print("No positive decisions found for the current user.")
                    self.isLoading = false
                }
                return
            }

            print("Found \(myDecisions.count) positive decisions made by current user.")

            var mutualMatchUserIDs: [CKRecord.ID] = []
            let group = DispatchGroup()

            for myDecision in myDecisions {
                guard let chatSessionRef = myDecision["chatSessionRef"] as? CKRecord.Reference,
                      let matchedUserRef = myDecision["matchedUserRef"] as? CKRecord.Reference else {
                    continue
                }

                group.enter()
                // Step B: For each, check other user's positive decision for the same session
                let otherUserPredicate = NSPredicate(format: "chatSessionRef == %@ AND decidingUserRef == %@ AND didConnect == TRUE", chatSessionRef, matchedUserRef)
                let otherUserQuery = CKQuery(recordType: "MatchDecision", predicate: otherUserPredicate)

                publicDatabase.perform(otherUserQuery, inZoneWith: nil) { otherDecisionRecords, error in
                    defer { group.leave() }
                    if let error = error {
                        print("Error fetching other user's decision for session \(chatSessionRef.recordID.recordName): \(error.localizedDescription)")
                        return
                    }
                    if let otherDecision = otherDecisionRecords?.first, otherDecisionRecords?.count == 1 {
                        print("Mutual match found for session \(chatSessionRef.recordID.recordName) with user \(matchedUserRef.recordID.recordName)")
                        mutualMatchUserIDs.append(matchedUserRef.recordID)
                    }
                }
            }

            group.notify(queue: .main) {
                print("Finished checking all decisions. Found \(mutualMatchUserIDs.count) mutual matches.")
                if mutualMatchUserIDs.isEmpty {
                    self.isLoading = false
                    return
                }

                var fetchedConnections: [MatchInfo] = []
                let profileGroup = DispatchGroup()

                for userID in Set(mutualMatchUserIDs) { // Use Set to avoid duplicate fetches if somehow involved in multiple sessions with same user
                    profileGroup.enter()
                    fetchUserProfileInfo(for: userID) { matchInfo in
                        if let info = matchInfo {
                            fetchedConnections.append(info)
                        }
                        profileGroup.leave()
                    }
                }

                profileGroup.notify(queue: .main) {
                    self.connections = fetchedConnections.sorted(by: { $0.name < $1.name }) // Sort alphabetically
                    self.isLoading = false
                    if self.connections.isEmpty && !mutualMatchUserIDs.isEmpty {
                         self.errorMessage = "Found mutual matches but could not fetch all profiles."
                    }
                    print("Finished fetching profiles. Displaying \(self.connections.count) connections.")
                }
            }
        }
    }

    private func fetchUserProfileInfo(for userRecordID: CKRecord.ID, completion: @escaping (MatchInfo?) -> Void) {
        // This fetches from the private UserProfile record type.
        // This assumes that the current user has permissions to fetch some user details of *other* users
        // if their Record ID is known, which is how MatchmakingView also works after discovering public profiles.
        let privateDatabase = CKContainer.default().privateCloudDatabase

        privateDatabase.fetch(withRecordID: userRecordID) { record, error in
            if let error = error {
                print("Error fetching user profile for \(userRecordID.recordName): \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let userProfileRecord = record else {
                print("No user profile record found for \(userRecordID.recordName)")
                completion(nil)
                return
            }

            let name = userProfileRecord["name"] as? String ?? "Unknown"
            let age = userProfileRecord["age"] as? Int ?? 0
            let homeCity = userProfileRecord["homeCity"] as? String ?? "Not specified"
            let bio = userProfileRecord["bio"] as? String ?? "No bio yet."
            let interests = userProfileRecord["interests"] as? [String] ?? []
            let photos = userProfileRecord["photos"] as? [CKAsset] ?? []

            let matchInfo = MatchInfo(recordID: userRecordID, name: name, age: age, homeCity: homeCity, bio: bio, interests: interests, photos: photos)
            completion(matchInfo)
        }
    }
}

struct MatchesView_Previews: PreviewProvider { // Corrected Preview struct name
    static var previews: some View {
        MatchesView()
            .environmentObject(AuthManager.preview) // Ensure AuthManager preview is available
    }
}

// Extend AuthManager for preview purposes if not already done
// extension AuthManager {
//     static var preview: AuthManager {
//         let manager = AuthManager()
//         // manager.userRecordID = CKRecord.ID(recordName: "previewUser") // Example
//         // manager.isAuthenticated = true
//         return manager
//     }
// }
