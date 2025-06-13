//
//  SpeedDatingView.swift
//  7PM Date
//
//  Created by AI Assistant on 2025-06-12
//

import SwiftUI
import CloudKit
import Combine // Import Combine for the Timer publisher
import UserNotifications // Import for notifications

// MARK: - Enums and Models
enum RSVPState {
    case unknown, notRSVPd, rsvpConfirmed, rsvpDisabled, checking
}

/// Represents the different states a user can be in during a live event.
enum LiveEventState: Equatable {
    case lobby
    case matching
    case inChat(sessionID: CKRecord.ID, match: MatchInfo)
    case postChat(sessionID: CKRecord.ID?, match: MatchInfo, didConnect: Bool)
    case eventEnded
}

/// A simple struct to hold information about a matched user.
struct MatchInfo: Identifiable, Equatable {
    let id = UUID()
    let recordID: CKRecord.ID?
    let name: String
    let age: Int
    let homeCity: String
    let bio: String
    let interests: [String]
    let photos: [CKAsset]

    static func == (lhs: MatchInfo, rhs: MatchInfo) -> Bool {
        return lhs.recordID == rhs.recordID &&
               lhs.name == rhs.name &&
               lhs.age == rhs.age &&
               lhs.homeCity == rhs.homeCity &&
               lhs.bio == rhs.bio &&
               lhs.interests == rhs.interests &&
               lhs.photos.map { $0.fileURL } == rhs.photos.map { $0.fileURL }
    }
}

/// Represents a single chat message.
struct ChatMessage: Identifiable, Equatable {
    let id: CKRecord.ID
    let text: String
    let isFromCurrentUser: Bool
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
    @State private var isDebugMode: Bool = false // Changed to false to hide
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
              let eventStartTime = calendar.date(bySettingHour: 19, minute: 2, second: 0, of: now) else {
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
                if isDebugMode {
                    debugPanel()
                }
                #endif
            }
            .padding()
            .navigationTitle("Speed Dating")
            .onAppear(perform: fetchUserRSVPStatus)
            .fullScreenCover(isPresented: $isLobbyPresented) {
                #if DEBUG
                LiveEventContainerView(isDebugMode: $isDebugMode, debugTime: $debugTime)
                    .environmentObject(authManager)
                #else
                LiveEventContainerView(isDebugMode: .constant(false), debugTime: .constant(Date()))
                    .environmentObject(authManager)
                #endif
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: userRSVPStatus)
        }
    }

    // MARK: - Subviews and CloudKit Logic
    @ViewBuilder
    private func mainContentView() -> some View {
        VStack(spacing: 16) {
            Text("Tonight's Speed Dating").font(.title2).bold().padding(.top)
            
            if isLobbyTime {
                Text("The event lobby is open!")
                    .font(.headline)
                    .transition(.slide)
                Text("Join now to meet people tonight.")
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                Button("Enter Lobby") {
                    isLobbyPresented = true
                }
                .font(.headline)
                .padding()
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .green.opacity(0.3), radius: 5)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLobbyPresented)
            } else if now < (Calendar.current.date(bySettingHour: 18, minute: 50, second: 0, of: now) ?? Date()) {
                switch userRSVPStatus {
                case .unknown, .checking:
                    ProgressView("Checking your RSVP status...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                case .notRSVPd:
                    Text("Join us tonight at 7 PM! RSVP now.").multilineTextAlignment(.center).padding(.horizontal)
                        .transition(.move(edge: .bottom))
                    if isProcessingRSVP {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        rsvpButton()
                    }
                case .rsvpConfirmed:
                    Text("🎉 You're RSVPd for tonight!").font(.headline).foregroundColor(.green)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 0.4), value: userRSVPStatus)
                    Text("The waiting room will open at 6:50 PM.").multilineTextAlignment(.center)
                        .transition(.opacity)
                case .rsvpDisabled:
                    Text("RSVP is currently unavailable.").foregroundColor(.orange).multilineTextAlignment(.center)
                        .transition(.scale)
                }
            } else {
                Text("The RSVP window for tonight's event has closed.").multilineTextAlignment(.center).padding(.horizontal)
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }

            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)").foregroundColor(.red).multilineTextAlignment(.center).padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.slide)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(16)
        .shadow(radius: 10)
    }

    private func rsvpButton() -> some View {
        Button("RSVP for Tonight", action: performRSVP)
            .font(.headline).padding().background(Color.blue.opacity(0.8)).foregroundColor(.white).cornerRadius(12)
            .shadow(color: .blue.opacity(0.3), radius: 5)
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessingRSVP)
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
                self.scheduleNotifications()
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
                    self.scheduleNotifications()
                }
            }
        }
    }

    private func scheduleNotifications() {
        let calendar = Calendar.current
        guard let eventTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date()),
              let fiveMinBefore = calendar.date(byAdding: .minute, value: -5, to: eventTime),
              let twoMinBefore = calendar.date(byAdding: .minute, value: -2, to: eventTime) else { return }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["fiveMinBefore", "twoMinBefore"])
                
                // 5 min before for everyone
                let fiveComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fiveMinBefore)
                let fiveTrigger = UNCalendarNotificationTrigger(dateMatching: fiveComponents, repeats: false)
                let fiveContent = UNMutableNotificationContent()
                fiveContent.title = "7PM Date Event Starting Soon!"
                fiveContent.body = "The speed dating event starts in 5 minutes. Join now!"
                fiveContent.sound = .default
                let fiveRequest = UNNotificationRequest(identifier: "fiveMinBefore", content: fiveContent, trigger: fiveTrigger)
                UNUserNotificationCenter.current().add(fiveRequest) { error in
                    if let error = error { print("Error scheduling 5 min notification: \(error)") }
                }
                
                // 2 min before if RSVPd
                if self.userRSVPStatus == .rsvpConfirmed {
                    let twoComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: twoMinBefore)
                    let twoTrigger = UNCalendarNotificationTrigger(dateMatching: twoComponents, repeats: false)
                    let twoContent = UNMutableNotificationContent()
                    twoContent.title = "7PM Date Event About to Start!"
                    twoContent.body = "Your RSVPd event starts in 2 minutes. Enter the lobby!"
                    twoContent.sound = .default
                    let twoRequest = UNNotificationRequest(identifier: "twoMinBefore", content: twoContent, trigger: twoTrigger)
                    UNUserNotificationCenter.current().add(twoRequest) { error in
                        if let error = error { print("Error scheduling 2 min notification: \(error)") }
                    }
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
                CloudKitTestHelper.seedMockUsers(for: authManager.userRecordID) { result in
                    switch result {
                    case .success(let message):
                        seedingStatus = message
                    case .failure(let error):
                        seedingStatus = "Error: \(error.localizedDescription)"
                    }
                }
            }.font(.caption)
            
            Button("Delete Account") {
                deleteAllUserData()
            }.font(.caption).foregroundColor(.red)
            
            Button("Logout") {
                authManager.signOut()
                // Optionally show alert or message "Logged out, data saved in iCloud."
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
    
    private func deleteAllUserData() {
        guard let userRecordID = authManager.userRecordID else { return }
        
        let privateDB = CKContainer.default().privateCloudDatabase
        let publicDB = CKContainer.default().publicCloudDatabase
        
        // Delete UserProfile
        privateDB.delete(withRecordID: userRecordID) { _, error in
            if let error = error {
                print("Error deleting UserProfile: \(error)")
            }
        }
        
        // Delete DiscoverableProfile
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        let discPredicate = NSPredicate(format: "userReference == %@", userRef)
        let discQuery = CKQuery(recordType: "DiscoverableProfile", predicate: discPredicate)
        publicDB.perform(discQuery, inZoneWith: nil) { records, error in
            if let records = records {
                let idsToDelete = records.map { $0.recordID }
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: idsToDelete)
                operation.modifyRecordsResultBlock = { result in
                    if case .failure(let error) = result {
                        print("Error deleting DiscoverableProfiles: \(error)")
                    }
                }
                publicDB.add(operation)
            }
        }
        
        // Delete SpeedDateRSVP
        let rsvpPredicate = NSPredicate(format: "userID == %@", userRecordID.recordName)
        let rsvpQuery = CKQuery(recordType: "SpeedDateRSVP", predicate: rsvpPredicate)
        privateDB.perform(rsvpQuery, inZoneWith: nil) { records, error in
            if let records = records {
                let idsToDelete = records.map { $0.recordID }
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: idsToDelete)
                operation.modifyRecordsResultBlock = { result in
                    if case .failure(let error) = result {
                        print("Error deleting RSVPs: \(error)")
                    }
                }
                privateDB.add(operation)
            }
        }
        
        // Delete ChatDecisions
        let decisionPredicate = NSPredicate(format: "userRef == %@", userRef)
        let decisionQuery = CKQuery(recordType: "ChatDecision", predicate: decisionPredicate)
        publicDB.perform(decisionQuery, inZoneWith: nil) { records, error in
            if let records = records {
                let idsToDelete = records.map { $0.recordID }
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: idsToDelete)
                operation.modifyRecordsResultBlock = { result in
                    if case .failure(let error) = result {
                        print("Error deleting ChatDecisions: \(error)")
                    }
                }
                publicDB.add(operation)
            }
        }
        
        // Delete BlockedUser (outgoing blocks)
        let blockedPredicate = NSPredicate(value: true) // Delete all, assuming small number
        let blockedQuery = CKQuery(recordType: "BlockedUser", predicate: blockedPredicate)
        privateDB.perform(blockedQuery, inZoneWith: nil) { records, error in
            if let records = records {
                let idsToDelete = records.map { $0.recordID }
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: idsToDelete)
                operation.modifyRecordsResultBlock = { result in
                    if case .failure(let error) = result {
                        print("Error deleting BlockedUsers: \(error)")
                    }
                }
                privateDB.add(operation)
            }
        }
        
        // After deletion, update auth state
        authManager.isOnboardingComplete = false
        authManager.isAuthenticated = false
        authManager.userRecordID = nil
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
    @State private var hasScheduledStart = false

    private var now: Date {
        #if DEBUG
        if isDebugMode { return debugTime }
        #endif
        return Date()
    }
    
    private var eventStartTime: Date {
        Calendar.current.date(bySettingHour: 19, minute: 2, second: 0, of: now) ?? Date()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    Text("Get Ready!")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                        .scaleEffect(1.05)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: timeRemaining)
                    Text("The event starts in...")
                        .font(.headline).foregroundColor(.gray)
                        .transition(.opacity)
                    Text(timeRemainingString())
                        .font(.system(size: 80, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .transition(.scale)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.5).padding(.top)
                        .animation(.easeInOut(duration: 0.3), value: timeRemaining)
                    Spacer()
                    #if DEBUG
                    if isDebugMode {
                        debugPanel()
                    }
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
                if remaining > 0 && !hasScheduledStart {
                    hasScheduledStart = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                        onEventStart()
                    }
                } else if remaining <= 0 {
                    onEventStart()
                }
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
        .transition(.opacity.combined(with: .scale))
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
                    Button("Event Start") { setDebugTime(hour: 19, minute: 2) }
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
    @State private var blockedUserIDs: [CKRecord.ID] = []
    @State private var showLowMatchSuggestion: Bool = false
    @State private var showAgeSuggestion: Bool = false
    @State private var suggestedCity: String?
    @State private var suggestedLowerBound: Int = 18
    @State private var suggestedUpperBound: Int = 99
    @State private var bypassSuggestion: Bool = false

    let allCities = ["Oceanside", "Carlsbad", "Encinitas", "La Jolla", "Hillcrest"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                if statusMessage.isEmpty {
                    Text("Finding date \(dateCount + 1) of 3...")
                        .font(.title)
                        .foregroundColor(.white)
                        .transition(.move(edge: .top))
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding()
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: statusMessage)
                } else {
                    Text(statusMessage)
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .transition(.opacity)
                }
                if showLowMatchSuggestion, let city = suggestedCity {
                    VStack(spacing: 10) {
                        Text("We found only a few potential matches with your current preferences. Would you like to add \(city) to your interested cities for more options tonight?")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .transition(.scale)
                        HStack {
                            Button("Yes, add it") {
                                addCityToProfile(city: city) {
                                    showLowMatchSuggestion = false
                                    findMatchFromCloudKit()
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .green.opacity(0.3), radius: 5)
                            .scaleEffect(1.0)
                            .animation(.spring(), value: showLowMatchSuggestion)

                            Button("No, continue") {
                                showLowMatchSuggestion = false
                                bypassSuggestion = true
                                findMatchFromCloudKit()
                            }
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .red.opacity(0.3), radius: 5)
                            .scaleEffect(1.0)
                            .animation(.spring(), value: showLowMatchSuggestion)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
                if showAgeSuggestion {
                    VStack(spacing: 10) {
                        Text("Still few matches. Would you like to expand your desired age range to \(suggestedLowerBound)-\(suggestedUpperBound)?")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .transition(.scale)
                        HStack {
                            Button("Yes, expand") {
                                updateAgeRangeInProfile(lower: suggestedLowerBound, upper: suggestedUpperBound) {
                                    showAgeSuggestion = false
                                    findMatchFromCloudKit()
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .green.opacity(0.3), radius: 5)

                            Button("No, continue") {
                                showAgeSuggestion = false
                                bypassSuggestion = true
                                findMatchFromCloudKit()
                            }
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .red.opacity(0.3), radius: 5)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
            }
        }
        .onAppear {
            bypassSuggestion = false
            fetchBlockedUserIDs {
                findMatchFromCloudKit()
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
    }

    private func fetchBlockedUserIDs(completion: @escaping () -> Void) {
        guard let currentUserRecordID = authManager.userRecordID else {
            statusMessage = "Could not identify current user."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { onNoMatchFound() }
            return
        }

        let predicate = NSPredicate(format: "blockedUntil > %@", Date() as CVarArg)
        let query = CKQuery(recordType: "BlockedUser", predicate: predicate)

        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let records = records {
                self.blockedUserIDs = records.compactMap { $0["blockedUserRef"] as? CKRecord.Reference }.map { $0.recordID }
            } else if let error = error {
                print("Error fetching blocked users: \(error.localizedDescription)")
            }
            completion()
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
            let currentUserHomeCity = currentUserPrivateRecord["homeCity"] as? String ?? ""
            let currentUserCities = currentUserPrivateRecord["cities"] as? [String] ?? []
            let desiredGenders = currentUserPrivateRecord["desiredGenders"] as? [String] ?? []
            let desiredLowerBound = currentUserPrivateRecord["desiredAgeLowerBound"] as? Int ?? 18
            let desiredUpperBound = currentUserPrivateRecord["desiredAgeUpperBound"] as? Int ?? 99
            
            let predicate = NSPredicate(format: "gender IN %@ AND age >= %d AND age <= %d AND cities CONTAINS %@", desiredGenders, desiredLowerBound, desiredUpperBound, currentUserHomeCity)
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
                    return userRef.recordID != currentUserRecordID && !alreadyMatchedRecordIDs.contains(userRef.recordID) && !self.blockedUserIDs.contains(userRef.recordID)
                }
                
                if !self.bypassSuggestion && potentialPublicMatches.count < 2 {
                    let availableCities = self.allCities.filter { !currentUserCities.contains($0) }
                    if !availableCities.isEmpty {
                        DispatchQueue.main.async {
                            self.suggestedCity = availableCities.randomElement()
                            self.showLowMatchSuggestion = true
                        }
                        return
                    } else {
                        DispatchQueue.main.async {
                            self.suggestedLowerBound = max(18, desiredLowerBound - 5)
                            self.suggestedUpperBound = min(99, desiredUpperBound + 5)
                            self.showAgeSuggestion = true
                        }
                        return
                    }
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
                        let matchHomeCity = matchPrivateRecord["homeCity"] as? String ?? ""
                        
                        let iFitTheirPrefs = matchDesiredGenders.contains(currentUserGender) &&
                                             (currentUserAge >= matchDesiredLower && currentUserAge <= matchDesiredUpper)
                        
                        let theyFitMyLocation = currentUserCities.contains(matchHomeCity)
                        
                        return iFitTheirPrefs && theyFitMyLocation
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
    
    private func addCityToProfile(city: String, completion: @escaping () -> Void) {
        guard let userRecordID = authManager.userRecordID else { return }
        
        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.fetch(withRecordID: userRecordID) { record, error in
            guard let record = record, error == nil else { return }
            
            var cities = record["cities"] as? [String] ?? []
            if !cities.contains(city) {
                cities.append(city)
                record["cities"] = cities
                privateDatabase.save(record) { _, error in
                    if error == nil {
                        completion()
                    }
                }
            } else {
                completion()
            }
        }
    }
    
    private func updateAgeRangeInProfile(lower: Int, upper: Int, completion: @escaping () -> Void) {
        guard let userRecordID = authManager.userRecordID else { return }
        
        let privateDatabase = CKContainer.default().privateCloudDatabase
        privateDatabase.fetch(withRecordID: userRecordID) { record, error in
            guard let record = record, error == nil else { return }
            
            record["desiredAgeLowerBound"] = lower
            record["desiredAgeUpperBound"] = upper
            privateDatabase.save(record) { _, error in
                if error == nil {
                    completion()
                }
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
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.2), radius: 3)
            } else {
                Text(message.text)
                    .padding(10)
                    .background(Color(.systemGray5).opacity(0.8))
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.2), radius: 3)
                Spacer()
            }
        }
        .transition(.slide.combined(with: .opacity))
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .transition(.opacity)
            }
        }
        .onAppear(perform: loadImage)
        .animation(.easeInOut, value: image)
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
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.scale)
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
                                        .transition(.move(edge: .leading))
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
            .transition(.move(edge: .bottom))
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
    
    // Timer for chat countdown
    private let chatTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // Timer to fetch new messages
    private let messageFetchTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

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
                            .transition(.opacity)
                        }
                    }
                    
                    Text(timeRemainingString())
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(timeRemaining <= 10 ? .red : .primary)
                        .padding(.top, 2)
                        .animation(.linear(duration: 1.0), value: timeRemaining)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.shadow(radius: 2))
                .transition(.move(edge: .top))

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
                .presentationDetents([.medium, .large])
        }
        .onReceive(chatTimer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining <= 150 { // 2.5 minutes elapsed
                    withAnimation { canViewProfile = true }
                }
            } else if !showPostChatButtons {
                withAnimation { showPostChatButtons = true }
                chatTimer.upstream.connect().cancel()
            }
        }
        .onReceive(messageFetchTimer) { _ in
            fetchMessages()
        }
        .onAppear(perform: fetchMessages)
        .animation(.default, value: messages)
    }
    
    private func fetchMessages() {
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
                let newMessages = records.map { record -> ChatMessage in
                    let text = record["text"] as? String ?? ""
                    let senderRef = record.creatorUserRecordID
                    return ChatMessage(id: record.recordID, text: text, isFromCurrentUser: senderRef?.recordName == authManager.userRecordID?.recordName)
                }
                
                // Only update if there are new messages to avoid constant UI refreshes
                if newMessages.count > self.messages.count {
                    self.messages = newMessages
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserRecordID = authManager.userRecordID else { return }
        
        let messageRecord = CKRecord(recordType: "ChatMessage")
        messageRecord["text"] = messageText
        messageRecord["chatSessionRef"] = CKRecord.Reference(recordID: sessionID, action: .deleteSelf)
        
        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.save(messageRecord) { record, error in
            DispatchQueue.main.async {
                if let record = record {
                    // Add the message locally immediately for a responsive feel
                    let newMessage = ChatMessage(id: record.recordID, text: messageText, isFromCurrentUser: true)
                    messages.append(newMessage)
                    messageText = ""
                } else {
                    // Handle error, maybe show an alert to the user
                    print("Error sending message: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    @ViewBuilder
    private func bottomActionView() -> some View {
        VStack(spacing: 0) {
            #if DEBUG
            if false {
                HStack {
                    Button("Skip to Reveal") { timeRemaining = 150 }
                        .font(.caption)
                    Spacer()
                    Button("End Chat") { timeRemaining = 0 }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
            }
            #endif

            if showPostChatButtons {
                HStack(spacing: 20) {
                    Button(action: { onDecision(match, false) }) {
                        Image(systemName: "xmark")
                            .font(.title).padding().background(Color.red.opacity(0.8))
                            .foregroundColor(.white).clipShape(Circle())
                            .shadow(color: .red.opacity(0.3), radius: 5)
                    }
                    .scaleEffect(1.0)
                    .animation(.spring(), value: showPostChatButtons)
                    Button(action: { onDecision(match, true) }) {
                        Image(systemName: "heart.fill")
                            .font(.title).padding().background(Color.green.opacity(0.8))
                            .foregroundColor(.white).clipShape(Circle())
                            .shadow(color: .green.opacity(0.3), radius: 5)
                    }
                    .scaleEffect(1.0)
                    .animation(.spring(), value: showPostChatButtons)
                }
                .padding().frame(maxWidth: .infinity).background(.white.opacity(0.9))
                .transition(.move(edge: .bottom))
            } else {
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
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .transition(.opacity)
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
    let sessionID: CKRecord.ID?
    let match: MatchInfo
    let didConnect: Bool
    var onFindNext: () -> Void

    @State private var showReportAlert: Bool = false
    @State private var reportReason: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: didConnect ? "heart.fill" : "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(didConnect ? .green : .red)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: didConnect)
                
                Text(didConnect ? "You connected with \(match.name)!" : "You passed on \(match.name).")
                    .font(.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                
                if !didConnect {
                    Button("Report this user") {
                        showReportAlert = true
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.orange.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .orange.opacity(0.3), radius: 5)
                    .scaleEffect(1.0)
                    .animation(.easeInOut, value: showReportAlert)
                }
                
                Button("Find Next Date", action: onFindNext)
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5)
                    .transition(.move(edge: .bottom))
            }
            .padding()
        }
        .alert("Report User", isPresented: $showReportAlert) {
            TextField("Reason (optional)", text: $reportReason)
            Button("Submit") {
                submitReport()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please provide a reason if possible.")
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
    }
    
    private func submitReport() {
        guard let sessionID = sessionID, let reporterID = EnvironmentObject<AuthManager>().wrappedValue.userRecordID, let reportedID = match.recordID else {
            return
        }
        
        let reportRecord = CKRecord(recordType: "Report")
        reportRecord["sessionRef"] = CKRecord.Reference(recordID: sessionID, action: .none)
        reportRecord["reporter"] = CKRecord.Reference(recordID: reporterID, action: .none)
        reportRecord["reported"] = CKRecord.Reference(recordID: reportedID, action: .none)
        reportRecord["reason"] = reportReason
        
        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.save(reportRecord) { _, error in
            if let error = error {
                print("Error submitting report: \(error.localizedDescription)")
            } else {
                // Optionally show success alert
            }
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
                    .rotationEffect(.degrees(360))
                    .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: true)
                
                Text("That's all for tonight!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .transition(.scale)

                Text("Check your Matches tab later to see who you connected with.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                
                Button("Back to Main Screen", action: onDismiss)
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5)
                    .transition(.move(edge: .bottom))
            }
            .padding()
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.5)).combined(with: .scale))
    }
}

// MARK: - Chat Session Logic

/// **Action Required:** You must create a new Record Type named `ChatDecision` in your CloudKit Public Database.
/// It must have the following fields and their corresponding indexes:
/// 1. `sessionRef` (Type: Reference, Action: None, Index: Queryable)
/// 2. `userRef` (Type: Reference, Action: None)
/// 3. `didConnect` (Type: Int (0 or 1), Index: Queryable) -> Use Int instead of Bool for better compatibility.
struct ChatSessionManager {
    let publicDB = CKContainer.default().publicCloudDatabase
    let privateDB = CKContainer.default().privateCloudDatabase
    let authManager: AuthManager

    func processUserDecision(sessionID: CKRecord.ID, matchedUserID: CKRecord.ID?, didConnect: Bool, completion: @escaping (Error?) -> Void) {
        guard let userRecordID = authManager.userRecordID else {
            let authError = NSError(domain: "com.7pmdate.app", code: 401, userInfo: [NSLocalizedDescriptionKey: "User is not authenticated."])
            completion(authError)
            return
        }

        // 1. Create and save the user's decision
        let decisionRecord = CKRecord(recordType: "ChatDecision")
        decisionRecord["sessionRef"] = CKRecord.Reference(recordID: sessionID, action: .none)
        decisionRecord["userRef"] = CKRecord.Reference(recordID: userRecordID, action: .none)
        decisionRecord["didConnect"] = didConnect ? 1 : 0 // Store as 1 for true, 0 for false

        publicDB.save(decisionRecord) { savedRecord, error in
            if let error = error {
                completion(error)
                return
            }

            if !didConnect, let matchedUserID = matchedUserID {
                // Create blocked record
                let blockedRecord = CKRecord(recordType: "BlockedUser")
                blockedRecord["blockedUserRef"] = CKRecord.Reference(recordID: matchedUserID, action: .none)
                blockedRecord["blockedUntil"] = Date().addingTimeInterval(30 * 24 * 3600) // 30 days
                self.privateDB.save(blockedRecord) { _, blockError in
                    if let blockError = blockError {
                        print("Error creating blocked record: \(blockError.localizedDescription)")
                    }
                }
            }

            #if DEBUG
            // In debug mode, if the user says "yes", automatically create a "yes" for the matched user to simulate a mutual connection for testing.
            if didConnect, let matchedUserID = matchedUserID {
                let mockDecisionRecord = CKRecord(recordType: "ChatDecision")
                mockDecisionRecord["sessionRef"] = CKRecord.Reference(recordID: sessionID, action: .none)
                mockDecisionRecord["userRef"] = CKRecord.Reference(recordID: matchedUserID, action: .none)
                mockDecisionRecord["didConnect"] = 1

                self.publicDB.save(mockDecisionRecord) { _, mockError in
                    if let mockError = mockError {
                        print("Debug-mode error simulating match: \(mockError.localizedDescription)")
                    }
                    // Regardless of the mock save, proceed with cleanup check
                     self.checkAndCleanupSession(sessionID: sessionID, justSavedDecision: savedRecord, completion: completion)
                }
            } else {
                 self.checkAndCleanupSession(sessionID: sessionID, justSavedDecision: savedRecord, completion: completion)
            }
            #else
            // In production, just check for cleanup
            self.checkAndCleanupSession(sessionID: sessionID, justSavedDecision: savedRecord, completion: completion)
            #endif
        }
    }

    private func checkAndCleanupSession(sessionID: CKRecord.ID, justSavedDecision: CKRecord?, completion: @escaping (Error?) -> Void) {
        let predicate = NSPredicate(format: "sessionRef == %@", CKRecord.Reference(recordID: sessionID, action: .none))
        let query = CKQuery(recordType: "ChatDecision", predicate: predicate)

        publicDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(error)
                return
            }

            guard var decisions = records else {
                completion(nil) // Should not happen, but safe to exit.
                return
            }
            
            // To avoid race conditions where a query result is stale, if the record
            // we just saved isn't in the results yet, add it to our local copy.
            if let savedDecision = justSavedDecision, !decisions.contains(where: { $0.recordID == savedDecision.recordID }) {
                decisions.append(savedDecision)
            }

            // Check if both users decided and if it was NOT a mutual 'yes'
            let wasMutualConnection = decisions.count >= 2 && decisions.allSatisfy { ($0["didConnect"] as? Int64 ?? 0) == 1 }

            // Condition to delete: EITHER both users decided and it wasn't a match, OR one user has already decided 'no'.
            let requiresCleanup = (decisions.count >= 2 && !wasMutualConnection) || decisions.contains { ($0["didConnect"] as? Int64 ?? 0) == 0 }

            if requiresCleanup {
                // Check if the session has been reported
                let reportPredicate = NSPredicate(format: "sessionRef == %@", CKRecord.Reference(recordID: sessionID, action: .none))
                let reportQuery = CKQuery(recordType: "Report", predicate: reportPredicate)
                
                self.publicDB.perform(reportQuery, inZoneWith: nil) { reportRecords, reportError in
                    if let reportError = reportError {
                        print("Error checking for reports: \(reportError.localizedDescription)")
                        // Proceed with delete even if error checking reports
                    }
                    
                    let isReported = !(reportRecords?.isEmpty ?? true)
                    
                    if isReported {
                        DispatchQueue.main.async {
                            completion(nil) // Don't delete if reported
                        }
                        return
                    }
                    
                    // Not a mutual match, or someone said no, and not reported. Delete the ChatSession record.
                    self.publicDB.delete(withRecordID: sessionID) { deletedRecordID, deleteError in
                        DispatchQueue.main.async {
                            if let deleteError = deleteError {
                                print("Failed to delete chat session \(sessionID.recordName): \(deleteError.localizedDescription)")
                            } else {
                                print("Chat session \(sessionID.recordName) and its messages cleaned up successfully.")
                            }
                            completion(deleteError)
                        }
                    }
                }
            } else {
                // It's a mutual match OR we are waiting for the other user to decide. Do nothing.
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}


struct LiveEventContainerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @Binding var isDebugMode: Bool
    @Binding var debugTime: Date
    
    @State private var eventState: LiveEventState = .lobby
    @State private var dateCount: Int = 0
    // State is now managed here, so it persists between matchmaking views
    @State private var alreadyMatchedRecordIDs: [CKRecord.ID] = []

    private var chatSessionManager: ChatSessionManager {
        ChatSessionManager(authManager: authManager)
    }
    
    var body: some View {
        Group {
            switch eventState {
            case .lobby:
                LobbyView(isDebugMode: $isDebugMode, debugTime: $debugTime, onEventStart: {
                    withAnimation(.easeInOut) {
                        self.eventState = .matching
                    }
                })
            case .matching:
                MatchmakingView(dateCount: dateCount, alreadyMatchedRecordIDs: $alreadyMatchedRecordIDs, onMatchFound: { match, sessionID in
                    withAnimation(.spring()) {
                        self.eventState = .inChat(sessionID: sessionID, match: match)
                    }
                }, onNoMatchFound: {
                    withAnimation {
                        self.eventState = .eventEnded
                    }
                })
            case .inChat(let sessionID, let match):
                ChatView(sessionID: sessionID, match: match, onDecision: { completedMatch, didConnect in
                    // Process the decision and handle message cleanup
                    chatSessionManager.processUserDecision(sessionID: sessionID, matchedUserID: completedMatch.recordID, didConnect: didConnect) { error in
                        if let error = error {
                            // Optionally handle the error, e.g., show an alert to the user
                            print("Error processing chat decision: \(error.localizedDescription)")
                        }
                    }
                    
                    // Continue the UI flow as before
                    self.dateCount += 1
                    withAnimation(.easeOut) {
                        self.eventState = .postChat(sessionID: didConnect ? nil : sessionID, match: completedMatch, didConnect: didConnect)
                    }
                })
            case .postChat(let sessionID, let match, let didConnect):
                PostChatView(sessionID: sessionID, match: match, didConnect: didConnect, onFindNext: {
                    if dateCount >= 3 {
                        withAnimation {
                            self.eventState = .eventEnded
                        }
                    } else {
                        withAnimation(.easeIn) {
                            self.eventState = .matching
                        }
                    }
                })
            case .eventEnded:
                EventEndView(onDismiss: {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
        .animation(.default, value: eventState)
    }
}

// MARK: - CloudKit Test Helper
#if DEBUG
struct CloudKitTestHelper {
    static func seedMockUsers(for currentUserRecordID: CKRecord.ID?, completion: @escaping (Result<String, Error>) -> Void) {
        let privateDatabase = CKContainer.default().privateCloudDatabase
        let publicDatabase = CKContainer.default().publicCloudDatabase
        
        // Add a mock profile for the "current user" to ensure matches can be found in testing.
        // This record will be associated with the currently logged-in iCloud user's ID.
        guard let currentUserRecordID = currentUserRecordID else {
            completion(.failure(NSError(domain: "com.7pmdate.app", code: 401, userInfo: [NSLocalizedDescriptionKey: "Cannot seed mock users without a logged-in user."])))
            return
        }

        let currentUserData: [String: Any] = ["name": "Alex (Me)", "age": 21, "gender": "Male", "homeCity": "San Diego", "cities": ["San Diego"], "bio": "iOS developer testing an app.", "interests": ["SwiftUI", "Testing"], "desiredGenders": ["Male", "Female"], "desiredAgeLowerBound": 20, "desiredAgeUpperBound": 35]

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
        
        // Create the current user's profile first
        let currentUserPrivateRecord = CKRecord(recordType: "UserProfile", recordID: currentUserRecordID)
        for (key, value) in currentUserData {
             currentUserPrivateRecord[key] = value as? CKRecordValue
        }
        privateRecordsToSave.append(currentUserPrivateRecord)
        
        let currentUserPublicRecord = CKRecord(recordType: "DiscoverableProfile")
        currentUserPublicRecord["age"] = currentUserData["age"] as? Int
        currentUserPublicRecord["gender"] = currentUserData["gender"] as? String
        currentUserPublicRecord["cities"] = currentUserData["cities"] as? [String]
        currentUserPublicRecord["userReference"] = CKRecord.Reference(recordID: currentUserRecordID, action: .deleteSelf)
        publicRecordsToSave.append(currentUserPublicRecord)


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



