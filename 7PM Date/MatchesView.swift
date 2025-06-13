// MatchesView.swift
//
//  MatchesView.swift
//  7PM Date
//
//  Created by AI Assistant on 2025-06-12
//

import SwiftUI
import CloudKit
import Combine

// MARK: - Models

struct Match: Identifiable, Hashable {
    let id: CKRecord.ID // Represents the UserProfile recordID of the matched person
    let sessionID: CKRecord.ID // Represents the ChatSession recordID
    let name: String
    let age: Int
    let profilePhoto: CKAsset?
    let lastMessage: String?
    let lastMessageDate: Date?

    // Manually conform to Hashable
    static func == (lhs: Match, rhs: Match) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - ViewModel

@MainActor
class MatchesViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let publicDB = CKContainer.default().publicCloudDatabase
    private let privateDB = CKContainer.default().privateCloudDatabase

    // Fetches matches using modern async/await for reliability
    func fetchMatches(for userRecordID: CKRecord.ID?, isManualRefresh: Bool = false) async {
        guard let userRecordID = userRecordID else {
            errorMessage = "Cannot fetch matches: User not authenticated."
            return
        }

        if !isManualRefresh {
            isLoading = true
        }
        errorMessage = nil

        do {
            // Step 1: Find all sessions where the current user and another user both said "yes".
            let currentUserRef = CKRecord.Reference(recordID: userRecordID, action: .none)
            let userDecisions = try await fetchDecisions(for: currentUserRef)

            guard !userDecisions.isEmpty else {
                self.matches = []
                self.isLoading = false
                return
            }

            let sessionRefs = userDecisions.compactMap { $0["sessionRef"] as? CKRecord.Reference }
            guard !sessionRefs.isEmpty else {
                self.matches = []
                self.isLoading = false
                return
            }
            
            let otherDecisions = try await fetchMatchingDecisions(for: sessionRefs, excluding: currentUserRef)
            guard !otherDecisions.isEmpty else {
                self.matches = []
                self.isLoading = false
                return
            }

            // Step 2: Fetch profiles and messages for these mutual match sessions.
            let mutualSessionRefs = otherDecisions.compactMap { $0["sessionRef"] as? CKRecord.Reference }
            let matchedUserRefs = otherDecisions.compactMap { $0["userRef"] as? CKRecord.Reference }

            // Skip reported sessions check to avoid error if record type not created
            // let reportedSessionIDs = try await fetchReportedSessions(for: mutualSessionRefs)

            // Fetch data concurrently for performance
            async let profiles = self.fetchProfiles(for: matchedUserRefs)
            async let allMessagesBySession = self.fetchAllMessages(for: mutualSessionRefs)

            let (fetchedProfiles, messagesBySessionID) = try await (profiles, allMessagesBySession)

            // Step 3: Combine the data into Match objects.
            let sessionMap = otherDecisions.reduce(into: [CKRecord.ID: CKRecord.Reference]()) { dict, record in
                if let sessionRef = record["sessionRef"] as? CKRecord.Reference, let userRef = record["userRef"] as? CKRecord.Reference {
                    dict[sessionRef.recordID] = userRef
                }
            }

            var finalMatches: [Match] = []
            for sessionRef in mutualSessionRefs {
                // if reportedSessionIDs.contains(sessionRef.recordID) { continue } // Skip reported sessions
                
                guard let matchedUserID = sessionMap[sessionRef.recordID]?.recordID,
                      let profile = fetchedProfiles[matchedUserID] else { continue }
                
                // Find the latest message on the client side
                let messagesForSession = messagesBySessionID[sessionRef.recordID] ?? []
                let lastMessageRecord = messagesForSession.max(by: { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) })

                let match = Match(
                    id: profile.recordID,
                    sessionID: sessionRef.recordID,
                    name: profile["name"] as? String ?? "Unknown",
                    age: profile["age"] as? Int ?? 0,
                    profilePhoto: (profile["photos"] as? [CKAsset])?.first,
                    lastMessage: lastMessageRecord?["text"] as? String,
                    lastMessageDate: lastMessageRecord?.creationDate
                )
                finalMatches.append(match)
            }
            
            self.matches = finalMatches.sorted { $0.lastMessageDate ?? .distantPast > $1.lastMessageDate ?? .distantPast }

        } catch {
            self.errorMessage = "Error fetching matches: \(error.localizedDescription)"
        }
        self.isLoading = false
    }
    
    // MARK: - Private Helper Functions using Async/Await

    private func fetchDecisions(for userRef: CKRecord.Reference) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "userRef == %@ AND didConnect == 1", userRef)
        let query = CKQuery(recordType: "ChatDecision", predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { try? $0.1.get() }
    }
    
    private func fetchMatchingDecisions(for sessionRefs: [CKRecord.Reference], excluding userRef: CKRecord.Reference) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "NOT (userRef == %@) AND sessionRef IN %@ AND didConnect == 1", userRef, sessionRefs)
        let query = CKQuery(recordType: "ChatDecision", predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { try? $0.1.get() }
    }

    private func fetchProfiles(for userRefs: [CKRecord.Reference]) async throws -> [CKRecord.ID: CKRecord] {
        let recordIDs = userRefs.map { $0.recordID }
        guard !recordIDs.isEmpty else { return [:] }
        let results = try await privateDB.records(for: recordIDs)
        return results.compactMapValues { try? $0.get() }
    }

    private func fetchAllMessages(for sessionRefs: [CKRecord.Reference]) async throws -> [CKRecord.ID: [CKRecord]] {
        guard !sessionRefs.isEmpty else { return [:] }
        
        let predicate = NSPredicate(format: "chatSessionRef IN %@", sessionRefs)
        let query = CKQuery(recordType: "ChatMessage", predicate: predicate)
        
        let (results, _) = try await publicDB.records(matching: query)
        let allMessages = results.compactMap { try? $0.1.get() }
        
        return Dictionary(grouping: allMessages, by: { ($0["chatSessionRef"] as! CKRecord.Reference).recordID })
    }
    
    private func fetchReportedSessions(for sessionRefs: [CKRecord.Reference]) async throws -> [CKRecord.ID] {
        guard !sessionRefs.isEmpty else { return [] }
        
        let predicate = NSPredicate(format: "sessionRef IN %@", sessionRefs)
        let query = CKQuery(recordType: "Report", predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { try? $0.1.get() }.compactMap { ($0["sessionRef"] as? CKRecord.Reference)?.recordID }
    }
}


// MARK: - Main Matches View
struct MatchesView: View {
    @StateObject private var viewModel = MatchesViewModel()
    @EnvironmentObject var authManager: AuthManager

    @State private var showUnmatchAlert = false
    @State private var showReportAlert = false
    @State private var selectedMatch: Match?
    @State private var reportReason: String = ""

    private let publicDB = CKContainer.default().publicCloudDatabase
    private let privateDB = CKContainer.default().privateCloudDatabase

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Finding your matches...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                        .transition(.opacity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .transition(.slide)
                        Button("Retry") {
                            Task {
                                await viewModel.fetchMatches(for: authManager.userRecordID)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 5)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                } else if viewModel.matches.isEmpty {
                    VStack(spacing: 20) {
                         Image(systemName: "heart.text.square")
                             .font(.system(size: 80))
                             .foregroundColor(.gray)
                             .transition(.scale)
                         Text("No Matches Yet")
                             .font(.title)
                             .fontWeight(.bold)
                         Text("Come back after an event to see who you connected with. Pull down to refresh.")
                             .font(.headline)
                             .foregroundColor(.secondary)
                             .multilineTextAlignment(.center)
                             .padding(.horizontal)
                    }
                    .refreshable {
                         await viewModel.fetchMatches(for: authManager.userRecordID, isManualRefresh: true)
                    }
                    .transition(.opacity)
                } else {
                    List {
                        ForEach(viewModel.matches) { match in
                            NavigationLink(destination: PersistentChatView(match: match).environmentObject(authManager)) {
                                matchRow(for: match)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Unmatch", role: .destructive) {
                                    selectedMatch = match
                                    showUnmatchAlert = true
                                }
                                .tint(.red)
                                
                                Button("Report") {
                                    selectedMatch = match
                                    showReportAlert = true
                                }
                                .tint(.orange)
                            }
                            .listRowBackground(Color.clear)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.fetchMatches(for: authManager.userRecordID, isManualRefresh: true)
                    }
                    .animation(.easeInOut, value: viewModel.matches)
                }
            }
            .navigationTitle("Matches")
            .task {
                if viewModel.matches.isEmpty {
                    await viewModel.fetchMatches(for: authManager.userRecordID)
                }
            }
            .alert("Confirm Unmatch", isPresented: $showUnmatchAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Unmatch", role: .destructive) {
                    if let match = selectedMatch {
                        Task {
                            await unmatchAndBlock(match: match)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to unmatch this person? You won't see them again for 30 days.")
            }
            .alert("Report User", isPresented: $showReportAlert) {
                TextField("Reason (optional)", text: $reportReason)
                Button("Cancel", role: .cancel) { }
                Button("Submit") {
                    if let match = selectedMatch {
                        Task {
                            await reportUser(match: match, reason: reportReason)
                            reportReason = ""
                        }
                    }
                }
            } message: {
                Text("Please provide a reason if possible.")
            }
        }
    }
    
    private func matchRow(for match: Match) -> some View {
        HStack(spacing: 15) {
            if let asset = match.profilePhoto {
                CloudKitImageView(asset: asset)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .shadow(color: .gray.opacity(0.2), radius: 3)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                    .shadow(color: .gray.opacity(0.2), radius: 3)
            }
            
            VStack(alignment: .leading) {
                Text(match.name)
                    .font(.headline)
                Text(match.lastMessage ?? "Tap to chat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func unmatchAndBlock(match: Match) async {
        guard let userRecordID = authManager.userRecordID else { return }
        
        // Update ChatDecision to 0
        let predicate = NSPredicate(format: "sessionRef == %@ AND userRef == %@", CKRecord.Reference(recordID: match.sessionID, action: .none), CKRecord.Reference(recordID: userRecordID, action: .none))
        let query = CKQuery(recordType: "ChatDecision", predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query)
            if let decisionRecord = results.compactMap({ try? $0.1.get() }).first {
                decisionRecord["didConnect"] = 0
                try await publicDB.modifyRecords(saving: [decisionRecord], deleting: [])
            }
        } catch {
            print("Error updating decision: \(error)")
        }
        
        // Create block
        let blockedRecord = CKRecord(recordType: "BlockedUser")
        blockedRecord["blockedUserRef"] = CKRecord.Reference(recordID: match.id, action: .none)
        blockedRecord["blockedUntil"] = Date().addingTimeInterval(30 * 24 * 3600)
        
        do {
            try await privateDB.modifyRecords(saving: [blockedRecord], deleting: [])
        } catch {
            print("Error creating block: \(error)")
        }
        
        // Refresh matches
        await viewModel.fetchMatches(for: userRecordID, isManualRefresh: true)
    }
    
    private func reportUser(match: Match, reason: String) async {
        guard let userRecordID = authManager.userRecordID else { return }
        
        let reportRecord = CKRecord(recordType: "Report")
        reportRecord["sessionRef"] = CKRecord.Reference(recordID: match.sessionID, action: .none)
        reportRecord["reporter"] = CKRecord.Reference(recordID: userRecordID, action: .none)
        reportRecord["reported"] = CKRecord.Reference(recordID: match.id, action: .none)
        reportRecord["reason"] = reason
        
        do {
            try await publicDB.modifyRecords(saving: [reportRecord], deleting: [])
        } catch {
            print("Error submitting report: \(error)")
        }
    }
}


// MARK: - Persistent Chat View
struct PersistentChatView: View {
    let match: Match
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var matchInfo: MatchInfo?
    @State private var isShowingProfile = false
    @State private var isLoadingProfile = true
    @State private var showUnmatchAlert = false
    @State private var showReportAlert = false
    @State private var reportReason: String = ""
    
    private let messageFetchTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let privateDB = CKContainer.default().privateCloudDatabase
    private let publicDB = CKContainer.default().publicCloudDatabase

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(match.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                Divider()
            }
            
            // Message List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.slide.combined(with: .opacity))
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastMessageID = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input field
            HStack {
                TextField("Type a message...", text: $messageText)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6).opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .gray.opacity(0.2), radius: 3)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.largeTitle)
                }
                .disabled(messageText.isEmpty)
                .opacity(messageText.isEmpty ? 0.5 : 1.0)
                .scaleEffect(messageText.isEmpty ? 0.9 : 1.0)
                .animation(.easeInOut, value: messageText)
            }
            .padding()
            .background(Material.bar)
            .transition(.move(edge: .bottom))
        }
        //.navigationTitle(match.name)  // REMOVED as per instructions
        //.navigationBarTitleDisplayMode(.inline)  // REMOVED as per instructions
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("View Profile") {
                    isShowingProfile = true
                }
                .opacity(isLoadingProfile ? 0 : 1)
                .overlay(isLoadingProfile ? ProgressView() : nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Unmatch") {
                        showUnmatchAlert = true
                    }
                    Button("Report") {
                        showReportAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingProfile) {
            if let matchInfo = matchInfo {
                ProfileDetailView(match: matchInfo)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Confirm Unmatch", isPresented: $showUnmatchAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unmatch", role: .destructive) {
                Task {
                    await unmatchAndBlock()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to unmatch this person? You won't see them again for 30 days.")
        }
        .alert("Report User", isPresented: $showReportAlert) {
            TextField("Reason (optional)", text: $reportReason)
            Button("Cancel", role: .cancel) { }
            Button("Submit") {
                Task {
                    await reportUser(reason: reportReason)
                    reportReason = ""
                }
            }
        } message: {
            Text("Please provide a reason if possible.")
        }
        .onAppear {
            fetchMessages()
            fetchMatchProfile()
        }
        .onReceive(messageFetchTimer) { _ in
            fetchMessages()
        }
        .animation(.default, value: messages)
    }
    
    private func fetchMatchProfile() {
        let recordID = match.id
        
        privateDB.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                self.isLoadingProfile = false
                if let record = record, error == nil {
                    let name = record["name"] as? String ?? "Unknown"
                    let age = record["age"] as? Int ?? 0
                    let homeCity = record["homeCity"] as? String ?? ""
                    let bio = record["bio"] as? String ?? ""
                    let interests = record["interests"] as? [String] ?? []
                    let photos = record["photos"] as? [CKAsset] ?? []
                    self.matchInfo = MatchInfo(recordID: recordID, name: name, age: age, homeCity: homeCity, bio: bio, interests: interests, photos: photos)
                } else {
                    print("Error fetching match profile: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
    
    private func fetchMessages() {
        let predicate = NSPredicate(format: "chatSessionRef == %@", CKRecord.Reference(recordID: match.sessionID, action: .none))
        let query = CKQuery(recordType: "ChatMessage", predicate: predicate)
        
        publicDB.perform(query, inZoneWith: nil) { records, error in
            guard let fetchedRecords = records, error == nil else {
                print("Error fetching messages: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                let sortedRecords = fetchedRecords.sorted { $0.creationDate ?? .distantPast < $1.creationDate ?? .distantPast }
                
                let newMessages = sortedRecords.map { record -> ChatMessage in
                    let text = record["text"] as? String ?? ""
                    let senderID = record.creatorUserRecordID
                    let isFromCurrentUser = senderID?.recordName == "__defaultOwner__"
                    return ChatMessage(id: record.recordID, text: text, isFromCurrentUser: isFromCurrentUser)
                }
                
                if newMessages != self.messages {
                    self.messages = newMessages
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageRecord = CKRecord(recordType: "ChatMessage")
        messageRecord["text"] = messageText
        messageRecord["chatSessionRef"] = CKRecord.Reference(recordID: match.sessionID, action: .none)
        
        let currentMessageText = messageText
        messageText = ""

        publicDB.save(messageRecord) { record, error in
            DispatchQueue.main.async {
                if let record = record {
                    let newMessage = ChatMessage(id: record.recordID, text: currentMessageText, isFromCurrentUser: true)
                    messages.append(newMessage)
                } else {
                    self.messageText = currentMessageText
                    print("Error sending message: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    private func unmatchAndBlock() async {
        guard let userRecordID = authManager.userRecordID else { return }
        
        // Update ChatDecision to 0
        let predicate = NSPredicate(format: "sessionRef == %@ AND userRef == %@", CKRecord.Reference(recordID: match.sessionID, action: .none), CKRecord.Reference(recordID: userRecordID, action: .none))
        let query = CKQuery(recordType: "ChatDecision", predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query)
            if let decisionRecord = results.compactMap({ try? $0.1.get() }).first {
                decisionRecord["didConnect"] = 0
                try await publicDB.modifyRecords(saving: [decisionRecord], deleting: [])
            }
        } catch {
            print("Error updating decision: \(error)")
        }
        
        // Create block
        let blockedRecord = CKRecord(recordType: "BlockedUser")
        blockedRecord["blockedUserRef"] = CKRecord.Reference(recordID: match.id, action: .none)
        blockedRecord["blockedUntil"] = Date().addingTimeInterval(30 * 24 * 3600)
        
        do {
            try await privateDB.modifyRecords(saving: [blockedRecord], deleting: [])
        } catch {
            print("Error creating block: \(error)")
        }
    }
    
    private func reportUser(reason: String) async {
        guard let userRecordID = authManager.userRecordID else { return }
        
        let reportRecord = CKRecord(recordType: "Report")
        reportRecord["sessionRef"] = CKRecord.Reference(recordID: match.sessionID, action: .none)
        reportRecord["reporter"] = CKRecord.Reference(recordID: userRecordID, action: .none)
        reportRecord["reported"] = CKRecord.Reference(recordID: match.id, action: .none)
        reportRecord["reason"] = reason
        
        do {
            try await publicDB.modifyRecords(saving: [reportRecord], deleting: [])
        } catch {
            print("Error submitting report: \(error)")
        }
    }
}

#Preview {
    // Create a dummy auth manager that can provide a user record for previews
    class PreviewAuthManager: AuthManager {
        override init() {
            super.init()
            self.userRecordID = CKRecord.ID(recordName: "previewUser")
        }
    }
    
    return MatchesView()
        .environmentObject(PreviewAuthManager())
}

