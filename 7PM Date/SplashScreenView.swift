import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isActive = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack {
                Image(systemName: "clock")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .padding()
                Text("7PM Date")
                    .font(.largeTitle)
                    .bold()
            }
        }
        .opacity(isActive ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .onAppear {
            // Show splash for 2 seconds, then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isActive = true
                authManager.isAuthenticated = false
            }
        }
    }
}

#Preview {
    SplashScreenView().environmentObject(AuthManager())
}
