import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Sign in to 7PM Date")
                .font(.title2)
                .bold()

            SignInWithAppleButton(.signIn, onRequest: { request in
                // Request full name and email for the *first time* a user signs in
                request.requestedScopes = [.fullName, .email]
            }, onCompletion: { result in
                // Pass the result to AuthManager for handling
                authManager.handleSignInWithAppleCompletion(result: result)
            })
            .frame(height: 50)
            .signInWithAppleButtonStyle(.black)
            .cornerRadius(8)
            .padding(.horizontal)
            Spacer()
        }
    }
}

#Preview {
    SignInView().environmentObject(AuthManager())
}

// Helper button using Apple API (for use in previews and main app)
struct CustomSignInWithAppleButton: View {
    let action: () -> Void
    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { _ in },
            onCompletion: { _ in action() }
        )
        .frame(maxWidth: .infinity)
    }
}
