import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("GitHub Todo")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                Text("GitHub Issues, refracted into a clear workflow.")
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect GitHub")
                        .font(.system(.headline, design: .rounded))
                    Text("Sign in to pick a repo and turn issues into focused todos.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await appState.signIn() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text(appState.isLoading ? "Connecting…" : "Sign in with GitHub")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(appState.isLoading)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
