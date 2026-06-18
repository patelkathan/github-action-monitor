import SwiftUI

struct LoginView: View {
    @ObservedObject var githubService = GitHubService.shared

    var body: some View {
        VStack(spacing: 24) {
            // Logo / Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 64, height: 64)

                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color("AccentColor", bundle: nil)) // system fallback is fine
                        .symbolRenderingMode(.hierarchical)
                }

                Text("TrayFlow")
                    .font(.system(.title3, design: .rounded))
                    .bold()

                Text("Keep track of your pipelines in real-time, built for a clean menu bar experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if githubService.isAuthenticating {
                if let response = githubService.deviceCodeResponse {
                    // Device Flow authorization code view
                    VStack(spacing: 16) {
                        Text("Verification Code")
                            .font(.caption)
                            .tracking(1)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Text(response.userCode)
                            .font(.system(.title, design: .monospaced))
                            .bold()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(8)
                            .onTapGesture {
                                copyCodeToClipboard(response.userCode)
                            }

                        VStack(spacing: 8) {
                            Button(action: {
                                copyAndOpenBrowser(response.userCode, urlString: response.verificationUri)
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy & Open GitHub")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                githubService.signOut()
                            }) {
                                Text("Cancel")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Waiting for authorization...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                } else {
                    ProgressView("Connecting to GitHub...")
                }
            } else {
                Button(action: {
                    githubService.startDeviceFlow()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.headline)
                        Text("Sign in with GitHub")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .foregroundColor(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if let error = githubService.authError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }

    private func copyCodeToClipboard(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(code, forType: .string)
    }

    private func copyAndOpenBrowser(_ code: String, urlString: String) {
        copyCodeToClipboard(code)
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
