//
//  SpeedDatingView.swift
//  7PM Date
//
//  Created by AI Assistant on 2025-06-12
//

import SwiftUI
import CloudKit
import Combine // Import Combine for the Timer publisher

// Define Notification Name for new chat messages
extension Notification.Name {
    static let DidReceiveNewChatMessage = Notification.Name("DidReceiveNewChatMessage")
}

// MARK: - Enums and Models
enum RSVPState {
    case unknown, notRSVPd, rsvpConfirmed, rsvpDisabled, checking
}

/// Represents the different states a user can be in during a live event.
enum LiveEventState {
    case lobby
    case matching
    case inChat(sessionID: CKRecord.ID, match: MatchInfo)
    case postChat(match: MatchInfo, didConnect: Bool)
    case eventEnded
}

/// A simple struct to hold information about a matched user.
struct MatchInfo: Identifiable {
    let id = UUID()
    let recordID: CKRecord.ID?
    let name: String
    let age: Int
    let homeCity: String
    let bio: String
    let interests: [String]
    let photos: [CKAsset]
}

/// Represents a single chat message.
struct ChatMessage: Identifiable, Equatable {
    let id: CKRecord.ID
    let text: String
    let isFromCurrentUser: Bool
    let chatSessionRef: CKRecord.Reference? // Added for associating message to a session

    // Equatable conformance
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}


// MARK: - Main View
struct SpeedDatingView: View {
    @EnvironmentObject var authManager: AuthManager

    // MARK: - State Properties
    @State private var userRSVPStatus: RSVPState = .unknown
    @State private var isProcessingRSVP: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLobbyPresented: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Debug Properties
    #if DEBUG
    @State private var isDebugMode: Bool = true // Default to true for easy testing
    @State private var debugTime: Date = Date()
    @State private var seedingStatus: String = ""
    #endif

    // MARK: - Computed Properties
    private var now: Date {
        #if DEBUG
        return isDebugMode ? debugTime : Date()
        #else
        return Date()
        #endif
    }
    
    private func normalizeDate(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    private var isLobbyTime: Bool {
        let calendar = Calendar.current
        guard let lobbyStartTime = calendar.date(bySettingHour: 18, minute: 50, second: 0, of: now),
              let eventStartTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) else {
            return false
        }
        return now >= lobbyStartTime && now < eventStartTime
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                mainContentView()
                Spacer()
                #if DEBUG
                debugPanel()
                #endif
            }
            .padding()
            .navigationTitle("Speed Dating")
            .onAppear(perform: fetchUserRSVPStatus)
            .fullScreenCover(isPresented: $isLobbyPresented) {
                LiveEventContainerView(isDebugMode: $isDebugMode, debugTime: $debugTime)
            }
        }
    }

    // MARK: - Subviews and CloudKit Logic
    @ViewBuilder
    private func mainContentView() -> some View {
        Text("Tonight's Speed Dating").font(.title2).bold().padding(.top)
        
        if isLobbyTime {
            Text("The event lobby is open!")
                .font(.headline)
            Text("Join now to meet people tonight.")
                .multilineTextAlignment(.center)
            Button("Enter Lobby") {
                isLobbyPresented = true
            }
            .font(.headline)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        } else if now < (Calendar.current.date(bySettingHour: 18, minute: 50, second: 0, of: now) ?? Date()) {
            switch userRSVPStatus {
            case .unknown, .checking:
                ProgressView("Checking your RSVP status...")
            case .notRSVPd:
                Text("Join us tonight at 7 PM! RSVP now.").multilineTextAlignment(.center).padding(.horizontal)
                if isProcessingRSVP { ProgressView() } else { rsvpButton() }
            case .rsvpConfirmed:
                Text("🎉 You're RSVPd for tonight!").font(.headline).foregroundColor(.green)
                Text("The waiting room will open at 6:50 PM.").multilineTextAlignment(.center)
            case .rsvpDisabled:
                Text("RSVP is currently unavailable.").foregroundColor(.orange).multilineTextAlignment(.center)
            }
        } else {
            Text("The RSVP window for tonight's event has closed.").multilineTextAlignment(.center).padding(.horizontal)
        }

        if let errorMessage = errorMessage {
            Text("Error: \(errorMessage)").foregroundColor(.red).multilineTextAlignment(.center).padding()
        }
    }

    private func rsvpButton() -> some View {
        Button("RSVP for Tonight", action: performRSVP)
            .font(.headline).padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)
    }
    
    private func fetchUserRSVPStatus() {
        guard let userRecordID = authManager.userRecordID else {
            self.errorMessage = "User not authenticated. Cannot fetch RSVP status."
            self.userRSVPStatus = .rsvpDisabled
            return
        }

        self.userRSVPStatus = .checking
        self.errorMessage = nil
        let normalizedEventDate = normalizeDate(now)

        let predicate = NSPredicate(format: "userID == %@ AND eventDate == %@", userRecordID.recordName, normalizedEventDate as CVarArg)
        let query = CKQuery(recordType: "SpeedDateRSVP", predicate: predicate)
        
        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error fetching RSVP status: \(error.localizedDescription)"
                    self.userRSVPStatus = .rsvpDisabled
                    return
                }

                if let foundRecords = records, !foundRecords.isEmpty {
                    self.userRSVPStatus = .rsvpConfirmed
                } else {
                    self.userRSVPStatus = .notRSVPd
                }
            }
        }
    }

    private func performRSVP() {
        guard let userRecordID = authManager.userRecordID else {
            self.errorMessage = "User not authenticated. Cannot RSVP."
            return
        }
        isProcessingRSVP = true
        errorMessage = nil
        let normalizedEventDate = normalizeDate(now)
        
        let rsvpRecord = CKRecord(recordType: "SpeedDateRSVP")
        rsvpRecord["userID"] = userRecordID.recordName
        rsvpRecord["eventDate"] = normalizedEventDate
        
        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.save(rsvpRecord) { record, error in
            DispatchQueue.main.async {
                self.isProcessingRSVP = false
                if let error = error {
                    self.errorMessage = "Failed to RSVP: \(error.localizedDescription)"
                } else {
                    self.userRSVPStatus = .rsvpConfirmed
                }
            }
        }
    }
    
    // MARK: - Debug Panel
    #if DEBUG
    @ViewBuilder
    private func debugPanel() -> some View {
        VStack {
            Text("Debug Controls").font(.caption).bold()
            Toggle("Enable Debug Mode", isOn: $isDebugMode.animation())
            
            if isDebugMode {
                DatePicker("Event Time", selection: $debugTime, displayedComponents: [.hourAndMinute])
                HStack {
                    Button("Before RSVP") { setDebugTime(hour: 17, minute: 0) }
                    Spacer()
                    Button("Lobby Time") { setDebugTime(hour: 18, minute: 55) }
                    Spacer()
                    Button("Event On") { setDebugTime(hour: 19, minute: 5) }
                }.buttonStyle(.bordered).font(.caption)
            }
            
            Button("Seed Mock Users") {
                seedingStatus = "Seeding..."
                CloudKitTestHelper.seedMockUsers { result in
                    switch result {
                    case .success(let message):
                        seedingStatus = message
                    case .failure(let error):
                        seedingStatus = "Error: \(error.localizedDescription)"
                    }
                }
            }.font(.caption)
            
            if !seedingStatus.isEmpty {
                Text(seedingStatus).font(.caption2).foregroundColor(.gray)
            }
            
        }.padding().background(Color(.systemGray6)).cornerRadius(10)
    }

    private func setDebugTime(hour: Int, minute: Int) {
        if let newTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) {
            debugTime = newTime
        }
    }
    #endif
}

// MARK: - Live Event Views

struct LobbyView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isDebugMode: Bool
    @Binding var debugTime: Date
    var onEventStart: () -> Void
    
    @State private var showExitAlert = false
    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var now: Date {
        #if DEBUG
        if isDebugMode { return debugTime }
        #endif
        return Date()
    }
    
    private var eventStartTime: Date {
        Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? Date()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    Text("Get Ready!")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text("The event starts in...")
                        .font(.headline).foregroundColor(.gray)
                    Text(timeRemainingString())
                        .font(.system(size: 80, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.5).padding(.top)
                    Spacer()
                    #if DEBUG
                    debugPanel()
                    #endif
                    Spacer()
                }
            }
            .onReceive(timer) { _ in
                let remaining = eventStartTime.timeIntervalSince(now)
                self.timeRemaining = max(0, remaining)
                if remaining <= 0 {
                    onEventStart()
                    timer.upstream.connect().cancel()
                }
            }
            .onAppear {
                let remaining = eventStartTime.timeIntervalSince(now)
                self.timeRemaining = max(0, remaining)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Leave") { showExitAlert = true }.tint(.white)
                }
            }
            .alert("Are you sure?", isPresented: $showExitAlert) {
                Button("Stay", role: .cancel) { }
                Button("Leave Event", role: .destructive) { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("If you leave, you will miss tonight's event.")
            }
        }
    }
    
    private func timeRemainingString() -> String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02i:%02i", minutes, seconds)
    }
    
    #if DEBUG
    @ViewBuilder
    private func debugPanel() -> some View {
        VStack {
            Text("Debug Controls").font(.caption).bold().foregroundColor(.white)
            Toggle("Enable Debug Mode", isOn: $isDebugMode.animation()).tint(.blue).foregroundColor(.white)
            if isDebugMode {
                DatePicker("Event Time", selection: $debugTime, displayedComponents: [.hourAndMinute])
                    .colorScheme(.dark)
                HStack {
                    Button("Lobby Time") { setDebugTime(hour: 18, minute: 55) }
                    Spacer()
                    Button("Event Start") { setDebugTime(hour: 19, minute: 0) }
                }.buttonStyle(.bordered).tint(.white).font(.caption)
            }
        }.padding().background(Color.white.opacity(0.1)).cornerRadius(10)
    }

    private func setDebugTime(hour: Int, minute: Int) {
        if let newTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) {
            debugTime = newTime
        }
    }
    #endif
}

struct MatchmakingView: View {
    @EnvironmentObject var authManager: AuthManager
    let dateCount: Int
    @Binding var alreadyMatchedRecordIDs: [CKRecord.ID]
    var onMatchFound: (MatchInfo, CKRecord.ID) -> Void
    var onNoMatchFound: () -> Void

    @State private var statusMessage: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                if statusMessage.isEmpty {
                    Text("Finding date \(dateCount + 1) of 3...")
                        .font(.title)
                        .foregroundColor(.white)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding()
                } else {
                    Text(statusMessage)
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .onAppear {
            findMatchFromCloudKit()
        }
    }

    private func findMatchFromCloudKit() {
        guard let currentUserRecordID = authManager.userRecordID else {
            statusMessage = "Could not identify current user."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { onNoMatchFound() }
            return
        }
        
        let privateDatabase = CKContainer.default().privateCloudDatabase
        let publicDatabase = CKContainer.default().publicCloudDatabase
        
        privateDatabase.fetch(withRecordID: currentUserRecordID) { currentUserPrivateRecord, error in
            guard let currentUserPrivateRecord = currentUserPrivateRecord, error == nil else {
                DispatchQueue.main.async {
                    statusMessage = "Could not fetch your profile to find matches."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { onNoMatchFound() }
                }
                return
            }

            let currentUserGender = currentUserPrivateRecord["gender"] as? String ?? ""
            let currentUserAge = currentUserPrivateRecord["age"] as? Int ?? 0
            let desiredGenders = currentUserPrivateRecord["desiredGenders"] as? [String] ?? []
            let desiredLowerBound = currentUserPrivateRecord["desiredAgeLowerBound"] as? Int ?? 18
            let desiredUpperBound = currentUserPrivateRecord["desiredAgeUpperBound"] as? Int ?? 99
            
            let predicate = NSPredicate(format: "gender IN %@ AND age >= %d AND age <= %d", desiredGenders, desiredLowerBound, desiredUpperBound)
            let query = CKQuery(recordType: "DiscoverableProfile", predicate: predicate)
            
            publicDatabase.perform(query, inZoneWith: nil) { records, error in
                guard let fetchedPublicRecords = records, error == nil else {
                    DispatchQueue.main.async {
                        statusMessage = "Error finding potential matches."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { onNoMatchFound() }
                    }
                    return
                }

                let potentialPublicMatches = fetchedPublicRecords.filter { record in
                    guard let userRef = record["userReference"] as? CKRecord.Reference else { return false }
                    return userRef.recordID != currentUserRecordID && !alreadyMatchedRecordIDs.contains(userRef.recordID)
                }
                
                guard !potentialPublicMatches.isEmpty else {
                    DispatchQueue.main.async {
                        statusMessage = "No new matches found that fit your preferences."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { onNoMatchFound() }
                    }
                    return
                }

                let potentialMatchPrivateIDs = potentialPublicMatches.compactMap { ($0["userReference"] as? CKRecord.Reference)?.recordID }
                
                let fetchOperation = CKFetchRecordsOperation(recordIDs: potentialMatchPrivateIDs)
                var fetchedPrivateRecords: [CKRecord] = []

                fetchOperation.perRecordResultBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        fetchedPrivateRecords.append(record)
                    case .failure(let error):
                        print("Error fetching individual record \(recordID): \(error)")
                    }
                }
                
                fetchOperation.fetchRecordsResultBlock = { result in
                    guard case .success = result else {
                        DispatchQueue.main.async { onNoMatchFound() }
                        return
                    }
                    
                    let twoWayMatches = fetchedPrivateRecords.filter { matchPrivateRecord in
                        let matchDesiredGenders = matchPrivateRecord["desiredGenders"] as? [String] ?? []
                        let matchDesiredLower = matchPrivateRecord["desiredAgeLowerBound"] as? Int ?? 18
                        let matchDesiredUpper = matchPrivateRecord["desiredAgeUpperBound"] as? Int ?? 99
                        
                        let iFitTheirPrefs = matchDesiredGenders.contains(currentUserGender) &&
                                             (currentUserAge >= matchDesiredLower && currentUserAge <= matchDesiredUpper)
                        
                        return iFitTheirPrefs
                    }

                    if let finalMatchRecord = twoWayMatches.randomElement() {
                        let newChatSessionRecord = CKRecord(recordType: "ChatSession")
                        let sessionID = newChatSessionRecord.recordID
                        
                        publicDatabase.save(newChatSessionRecord) { record, error in
                            DispatchQueue.main.async {
                                guard record != nil, error == nil else {
                                    onNoMatchFound()
                                    return
                                }
                                
                                let name = finalMatchRecord["name"] as? String ?? "Unknown"
                                let age = finalMatchRecord["age"] as? Int ?? 0
                                let homeCity = finalMatchRecord["homeCity"] as? String ?? ""
                                let bio = finalMatchRecord["bio"] as? String ?? "Loves having a good time!"
                                let interests = finalMatchRecord["interests"] as? [String] ?? ["Mystery"]
                                let photos = finalMatchRecord["photos"] as? [CKAsset] ?? []
                                
                                let matchInfo = MatchInfo(recordID: finalMatchRecord.recordID, name: name, age: age, homeCity: homeCity, bio: bio, interests: interests, photos: photos)
                                
                                alreadyMatchedRecordIDs.append(finalMatchRecord.recordID)
                                onMatchFound(matchInfo, sessionID)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            statusMessage = "No one fit your mutual preferences."
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { onNoMatchFound() }
                        }
                    }
                }
                privateDatabase.add(fetchOperation)
            }
        }
    }
}


struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
                Text(message.text)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            } else {
                Text(message.text)
                    .padding(10)
                    .background(Color(.systemGray5))
                    .cornerRadius(16)
                Spacer()
            }
        }
    }
}

/// A view to asynchronously load and display an image from a CKAsset.
struct CloudKitImageView: View {
    @State private var image: Image?
    @State private var isLoading = false
    let asset: CKAsset

    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        guard image == nil, let fileURL = asset.fileURL else { return }
        isLoading = true
        
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = Image(uiImage: uiImage)
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

struct ProfileDetailView: View {
    let match: MatchInfo
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    if !match.photos.isEmpty {
                        TabView {
                            ForEach(match.photos, id: \.fileURL) { photoAsset in
                                CloudKitImageView(asset: photoAsset)
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("\(match.name), \(match.age)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(match.homeCity)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(match.bio)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interests")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(match.interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}


struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager
    let sessionID: CKRecord.ID
    let match: MatchInfo
    var onDecision: (MatchInfo, Bool) -> Void

    @State private var timeRemaining: Int = 300
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var showPostChatButtons = false
    @State private var canViewProfile = false
    @State private var isShowingProfile = false
    @State private var newMessageObserver: Any? // For NotificationCenter observer
    
    // Timer for chat countdown
    private let chatTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // Timer to fetch new messages - THIS WILL BE REMOVED
    // private let messageFetchTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(match.name)
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("\(match.age) years old")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if canViewProfile {
                            Button("View Profile") {
                                isShowingProfile = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Text(timeRemainingString())
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(timeRemaining <= 10 ? .red : .primary)
                        .padding(.top, 2)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.shadow(radius: 2))

                // Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                // Conditional view for input/decision
                bottomActionView()
            }
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileDetailView(match: match)
        }
        .onReceive(chatTimer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining <= 120 { // 2 minutes remaining
                    withAnimation { canViewProfile = true }
                }
            } else if !showPostChatButtons {
                withAnimation { showPostChatButtons = true }
                chatTimer.upstream.connect().cancel()
            }
        }
        // .onReceive(messageFetchTimer) { _ in // REMOVED Polling
        //     fetchMessages()
        // }
        .onAppear {
            // Initial fetch of messages
            fetchMessages()
            // Subscribe to new message notifications
            newMessageObserver = NotificationCenter.default.addObserver(
                forName: .DidReceiveNewChatMessage,
                object: nil,
                queue: .main
            ) { notification in
                handleNewMessageNotification(notification)
            }
        }
        .onDisappear {
            // Unsubscribe from new message notifications
            if let observer = newMessageObserver {
                NotificationCenter.default.removeObserver(observer)
                newMessageObserver = nil
            }
        }
    }

    private func handleNewMessageNotification(_ notification: Notification) {
        guard let newMessage = notification.userInfo?["message"] as? ChatMessage else {
            print("ChatView: Failed to extract ChatMessage from notification.")
            return
        }

        // Check if the message belongs to the current chat session
        guard newMessage.chatSessionRef?.recordID == self.sessionID else {
            print("ChatView: Received message for different session (\(newMessage.chatSessionRef?.recordID.recordName ?? "N/A")) than current (\(self.sessionID.recordName)).")
            return
        }

        // Avoid duplicates
        if !messages.contains(where: { $0.id == newMessage.id }) {
            messages.append(newMessage)
            // messages.sort(by: { $0.timestamp < $1.timestamp }) // If timestamp becomes part of ChatMessage
            print("ChatView: New message \(newMessage.id) added to session \(self.sessionID.recordName).")
        } else {
            print("ChatView: Duplicate message \(newMessage.id) for session \(self.sessionID.recordName) not added.")
        }
    }
    
    private func fetchMessages() { // This can still be used for initial load
        guard let _ = authManager.userRecordID else { return }
        
        let predicate = NSPredicate(format: "chatSessionRef == %@", CKRecord.Reference(recordID: sessionID, action: .none))
        let query = CKQuery(recordType: "ChatMessage", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.perform(query, inZoneWith: nil) { records, error in
            guard let records = records, error == nil else {
                print("Error fetching messages: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.messages = records.map { record -> ChatMessage in
                    let text = record["text"] as? String ?? ""
                    let senderRef = record.creatorUserRecordID
                    let chatSessionRef = record["chatSessionRef"] as? CKRecord.Reference
                    return ChatMessage(id: record.recordID, text: text, isFromCurrentUser: senderRef?.recordName == authManager.userRecordID?.recordName, chatSessionRef: chatSessionRef)
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserRecordID = authManager.userRecordID else { return }
        
        let messageRecord = CKRecord(recordType: "ChatMessage")
        messageRecord["text"] = messageText
        let sessionReference = CKRecord.Reference(recordID: sessionID, action: .deleteSelf)
        messageRecord["chatSessionRef"] = sessionReference
        
        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.save(messageRecord) { record, error in
            DispatchQueue.main.async {
                if let record = record {
                    // Add the message locally immediately for a responsive feel
                    let newMessage = ChatMessage(id: record.recordID, text: messageText, isFromCurrentUser: true, chatSessionRef: sessionReference)
                    messages.append(newMessage)
                    messageText = ""
                } else {
                    // Handle error, maybe show an alert to the user
                    print("Error sending message: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
    }
    
    @ViewBuilder
    private func bottomActionView() -> some View {
        VStack(spacing: 0) {
            #if DEBUG
            HStack {
                Button("Skip to Reveal") { timeRemaining = 120 }
                    .font(.caption)
                Spacer()
                Button("End Chat") { timeRemaining = 0 }
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            #endif

            if showPostChatButtons {
                HStack(spacing: 20) {
                    Button(action: { onDecision(match, false) }) {
                        Image(systemName: "xmark")
                            .font(.title).padding().background(Color.red)
                            .foregroundColor(.white).clipShape(Circle())
                    }
                    Button(action: { onDecision(match, true) }) {
                        Image(systemName: "heart.fill")
                            .font(.title).padding().background(Color.green)
                            .foregroundColor(.white).clipShape(Circle())
                    }
                }
                .padding().frame(maxWidth: .infinity).background(.white)
            } else {
                HStack {
                    TextField("Type a message...", text: $messageText)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(Color.white)
            }
        }
    }

    private func timeRemainingString() -> String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%01i:%02i", minutes, seconds)
    }
}

struct PostChatView: View {
    let match: MatchInfo
    let didConnect: Bool
    var onFindNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: didConnect ? "heart.fill" : "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(didConnect ? .green : .red)
                
                Text(didConnect ? "You connected with \(match.name)!" : "You passed on \(match.name).")
                    .font(.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button("Find Next Date", action: onFindNext)
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct EventEndView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                
                Text("That's all for tonight!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Check your Matches tab later to see who you connected with.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Back to Main Screen", action: onDismiss)
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}


struct LiveEventContainerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager // Ensure AuthManager is in the environment
    @Binding var isDebugMode: Bool
    @Binding var debugTime: Date
    
    @State private var eventState: LiveEventState = .lobby
    @State private var dateCount: Int = 0
    // State is now managed here, so it persists between matchmaking views
    @State private var alreadyMatchedRecordIDs: [CKRecord.ID] = []

    
    var body: some View {
        switch eventState {
        case .lobby:
            LobbyView(isDebugMode: $isDebugMode, debugTime: $debugTime, onEventStart: {
                self.eventState = .matching
            })
        case .matching:
            MatchmakingView(dateCount: dateCount, alreadyMatchedRecordIDs: $alreadyMatchedRecordIDs, onMatchFound: { match, sessionID in
                self.eventState = .inChat(sessionID: sessionID, match: match)
            }, onNoMatchFound: {
                self.eventState = .eventEnded
            })
        case .inChat(let sessionID, let match):
            ChatView(sessionID: sessionID, match: match, onDecision: { completedMatch, didConnect in
                // MARK: Store Match Decision
                saveMatchDecision(chatSessionID: sessionID, matchedUser: completedMatch, decision: didConnect)

                self.dateCount += 1
                self.eventState = .postChat(match: completedMatch, didConnect: didConnect)
            })
        case .postChat(let match, let didConnect):
            PostChatView(match: match, didConnect: didConnect, onFindNext: {
                if dateCount >= 3 {
                    self.eventState = .eventEnded
                } else {
                    self.eventState = .matching
                }
            })
        case .eventEnded:
            EventEndView(onDismiss: {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func saveMatchDecision(chatSessionID: CKRecord.ID, matchedUser: MatchInfo, decision: Bool) {
        guard let currentUserRecordID = authManager.userRecordID else {
            print("Error: Current user RecordID not found. Cannot save match decision.")
            return
        }
        guard let matchedUserRecordID = matchedUser.recordID else {
            print("Error: Matched user RecordID not found. Cannot save match decision.")
            return
        }

        let decisionRecord = CKRecord(recordType: "MatchDecision")
        decisionRecord["chatSessionRef"] = CKRecord.Reference(recordID: chatSessionID, action: .none)
        decisionRecord["decidingUserRef"] = CKRecord.Reference(recordID: currentUserRecordID, action: .none)
        decisionRecord["matchedUserRef"] = CKRecord.Reference(recordID: matchedUserRecordID, action: .none)
        decisionRecord["didConnect"] = decision as CKRecordValue // Store as Boolean
        decisionRecord["decisionTimestamp"] = Date() as CKRecordValue

        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.save(decisionRecord) { record, error in
            if let error = error {
                print("Error saving MatchDecision: \(error.localizedDescription)")
                // Even if saving decision fails, the UI flow continues.
                // Consider if more robust error handling is needed here.
            } else {
                print("Successfully saved MatchDecision for session \(chatSessionID.recordName) with user \(matchedUserRecordID.recordName). Decision: \(decision)")
                // After successfully saving, check for mutual match and handle messages.
                self.checkMatchAndHandleMessages(for: chatSessionID, currentUserRecordID: currentUserRecordID, matchedUserRecordID: matchedUserRecordID)
            }
        }
    }

    private func checkMatchAndHandleMessages(for chatSessionID: CKRecord.ID, currentUserRecordID: CKRecord.ID, matchedUserRecordID: CKRecord.ID) {
        let publicDatabase = CKContainer.default().publicCloudDatabase
        let predicate = NSPredicate(format: "chatSessionRef == %@", CKRecord.Reference(recordID: chatSessionID, action: .none))
        let query = CKQuery(recordType: "MatchDecision", predicate: predicate)

        publicDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching MatchDecisions for session \(chatSessionID.recordName): \(error.localizedDescription)")
                return
            }

            guard let decisionRecords = records else {
                print("No MatchDecision records found for session \(chatSessionID.recordName), though expected at least one.")
                return
            }

            print("Fetched \(decisionRecords.count) MatchDecision records for session \(chatSessionID.recordName).")

            if decisionRecords.count == 2 {
                var currentUserDecision = false
                var matchedUserDecision = false
                var decisionsFound = 0

                for record in decisionRecords {
                    if let decidingUserRef = record["decidingUserRef"] as? CKRecord.Reference,
                       let didConnect = record["didConnect"] as? Bool {
                        if decidingUserRef.recordID.recordName == currentUserRecordID.recordName {
                            currentUserDecision = didConnect
                            decisionsFound += 1
                        } else if decidingUserRef.recordID.recordName == matchedUserRecordID.recordName {
                            matchedUserDecision = didConnect
                            decisionsFound += 1
                        }
                    }
                }

                if decisionsFound == 2 { // Ensure both decisions were properly identified
                    if currentUserDecision && matchedUserDecision {
                        print("Mutual match for session \(chatSessionID.recordName)! Messages will be kept.")
                    } else {
                        print("Not a mutual match for session \(chatSessionID.recordName). Deleting messages.")
                        self.deleteChatMessages(for: chatSessionID)
                    }
                } else {
                     print("Could not definitively determine both users' decisions from the fetched records for session \(chatSessionID.recordName). Found \(decisionsFound) valid decisions.")
                }
            } else if decisionRecords.count == 1 {
                print("Only one decision found for session \(chatSessionID.recordName). Waiting for the other user.")
                // Optionally, check if the single decision is from the current user and is a 'pass'.
                // If so, and if business logic allowed immediate deletion on one user's 'pass',
                // messages could be deleted here. However, current logic waits for two decisions.
            } else {
                 print("Unexpected number of decisions (\(decisionRecords.count)) found for session \(chatSessionID.recordName). Expected 1 or 2.")
            }
        }
    }

    private func deleteChatMessages(for chatSessionID: CKRecord.ID) {
        let publicDatabase = CKContainer.default().publicCloudDatabase
        let predicate = NSPredicate(format: "chatSessionRef == %@", CKRecord.Reference(recordID: chatSessionID, action: .none))
        let query = CKQuery(recordType: "ChatMessage", predicate: predicate)

        publicDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching ChatMessages for deletion in session \(chatSessionID.recordName): \(error.localizedDescription)")
                return
            }

            guard let chatMessageRecords = records, !chatMessageRecords.isEmpty else {
                print("No ChatMessages found to delete for session \(chatSessionID.recordName).")
                return
            }

            let recordIDsToDelete = chatMessageRecords.map { $0.recordID }
            print("Attempting to delete \(recordIDsToDelete.count) messages for session \(chatSessionID.recordName).")

            let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)

            // Handle per-record errors if needed, though CloudKit often gives a single error for the batch.
            modifyRecordsOperation.perRecordDeleteBlock = { recordID, error in
                 if let error = error {
                    print("Error deleting message \(recordID.recordName): \((error as? CKError)?.localizedDescription ?? error.localizedDescription)")
                 } else {
                    // print("Successfully marked message \(recordID.recordName) for deletion.")
                 }
            }

            modifyRecordsOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("Successfully deleted \(recordIDsToDelete.count) chat messages for session \(chatSessionID.recordName).")
                case .failure(let error):
                     // Check for partial failures if specific per-record errors are not handled or are insufficient
                    if let ckError = error as? CKError, let partialErrors = ckError.partialErrorsByItemID {
                        var allRecordsSuccessfullyDeleted = true
                        for (recordID, partialError) in partialErrors {
                            if let partialCKError = partialError as? CKError {
                                // "Record not found" (serverRecordChanged or unknownItem) can be ignored if another user already deleted them.
                                if partialCKError.code == .serverRecordChanged || partialCKError.code == .unknownItem {
                                    print("Message \(recordID.recordName) was already deleted or changed by another user.")
                                } else {
                                    allRecordsSuccessfullyDeleted = false
                                    print("Failed to delete message \(recordID.recordName): \(partialCKError.localizedDescription)")
                                }
                            } else {
                                allRecordsSuccessfullyDeleted = false
                                print("Failed to delete message \(recordID.recordName): \(partialError.localizedDescription)")
                            }
                        }
                        if allRecordsSuccessfullyDeleted && partialErrors.count == recordIDsToDelete.count {
                             print("All messages for session \(chatSessionID.recordName) were already deleted or handled.")
                        } else if allRecordsSuccessfullyDeleted {
                             print("Some messages for session \(chatSessionID.recordName) successfully deleted, others already gone.")
                        } else {
                             print("Partial failure deleting messages for session \(chatSessionID.recordName). Error: \(error.localizedDescription)")
                        }
                    } else {
                        print("Failed to delete chat messages for session \(chatSessionID.recordName): \(error.localizedDescription)")
                    }
                }
            }
            publicDatabase.add(modifyRecordsOperation)
        }
    }
}

// MARK: - CloudKit Test Helper
#if DEBUG
struct CloudKitTestHelper {
    static func seedMockUsers(completion: @escaping (Result<String, Error>) -> Void) {
        let privateDatabase = CKContainer.default().privateCloudDatabase
        let publicDatabase = CKContainer.default().publicCloudDatabase
        
        let mockData: [[String: Any]] = [
            // --- MUTUAL MATCHES (They are Male, 21-30, and want a Male who is 21) ---
            ["name": "Liam", "age": 25, "gender": "Male", "homeCity": "Carlsbad", "cities": ["Carlsbad", "Oceanside"], "bio": "Surfer and software engineer.", "interests": ["Surfing", "Tech"], "desiredGenders": ["Male"], "desiredAgeLowerBound": 21, "desiredAgeUpperBound": 30],
            ["name": "Noah", "age": 29, "gender": "Male", "homeCity": "Oceanside", "cities": ["Oceanside"], "bio": "Just a guy who likes long walks on the beach... to the taco shop.", "interests": ["Tacos", "Craft Beer"], "desiredGenders": ["Male", "Female"], "desiredAgeLowerBound": 20, "desiredAgeUpperBound": 32],
            ["name": "Ethan", "age": 22, "gender": "Male", "homeCity": "Encinitas", "cities": ["Encinitas", "La Jolla"], "bio": "Student at UCSD, love to skate and find new coffee spots.", "interests": ["Skateboarding", "Coffee"], "desiredGenders": ["Male"], "desiredAgeLowerBound": 21, "desiredAgeUpperBound": 25],
            
            // --- NON-MUTUAL MATCHES ---
            ["name": "Oliver", "age": 28, "gender": "Male", "homeCity": "La Jolla", "cities": ["La Jolla"], "bio": "Architect and travel blogger.", "interests": ["Architecture", "Travel"], "desiredGenders": ["Female"], "desiredAgeLowerBound": 25, "desiredAgeUpperBound": 35],
            ["name": "James", "age": 30, "gender": "Male", "homeCity": "Carlsbad", "cities": ["Carlsbad"], "bio": "Fitness coach and entrepreneur.", "interests": ["Fitness", "Business"], "desiredGenders": ["Male"], "desiredAgeLowerBound": 22, "desiredAgeUpperBound": 28]
        ]

        var privateRecordsToSave: [CKRecord] = []
        var publicRecordsToSave: [CKRecord] = []
        
        let placeholderImage = UIImage(systemName: "person.crop.circle")!
        let placeholderImageData = placeholderImage.jpegData(compressionQuality: 0.8)!
        let tempDirectory = FileManager.default.temporaryDirectory
        
        for userData in mockData {
            let privateRecordID = CKRecord.ID(recordName: UUID().uuidString)
            let privateRecord = CKRecord(recordType: "UserProfile", recordID: privateRecordID)
            
            let imageFileName = UUID().uuidString
            let imageURL = tempDirectory.appendingPathComponent(imageFileName)
            try? placeholderImageData.write(to: imageURL)
            let photoAsset = CKAsset(fileURL: imageURL)
            
            privateRecord["name"] = userData["name"] as? String
            privateRecord["age"] = userData["age"] as? Int
            privateRecord["gender"] = userData["gender"] as? String
            privateRecord["homeCity"] = userData["homeCity"] as? String
            privateRecord["cities"] = userData["cities"] as? [String]
            privateRecord["bio"] = userData["bio"] as? String
            privateRecord["interests"] = userData["interests"] as? [String]
            privateRecord["photos"] = [photoAsset]
            privateRecord["desiredGenders"] = userData["desiredGenders"] as? [String]
            privateRecord["desiredAgeLowerBound"] = userData["desiredAgeLowerBound"] as? Int
            privateRecord["desiredAgeUpperBound"] = userData["desiredAgeUpperBound"] as? Int
            privateRecordsToSave.append(privateRecord)
            
            let publicRecord = CKRecord(recordType: "DiscoverableProfile")
            publicRecord["age"] = userData["age"] as? Int
            publicRecord["gender"] = userData["gender"] as? String
            publicRecord["cities"] = userData["cities"] as? [String]
            publicRecord["userReference"] = CKRecord.Reference(recordID: privateRecordID, action: .deleteSelf)
            publicRecordsToSave.append(publicRecord)
        }

        let savePrivateOperation = CKModifyRecordsOperation(recordsToSave: privateRecordsToSave, recordIDsToDelete: nil)
        savePrivateOperation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                let savePublicOperation = CKModifyRecordsOperation(recordsToSave: publicRecordsToSave, recordIDsToDelete: nil)
                savePublicOperation.modifyRecordsResultBlock = { publicResult in
                    DispatchQueue.main.async {
                        switch publicResult {
                        case .success:
                            completion(.success("Successfully seeded \(publicRecordsToSave.count) users."))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
                publicDatabase.add(savePublicOperation)
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        privateDatabase.add(savePrivateOperation)
    }
}
#endif
