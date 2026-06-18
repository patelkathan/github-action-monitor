import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @ObservedObject var githubService = GitHubService.shared
    
    // Settings view configuration
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Close settings modal / switch back to main view
                    NotificationCenter.default.post(name: Notification.Name("CloseSettings"), object: nil)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Section 1: General Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General Settings")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.secondary)
                        
                        // Launch at login toggle
                        Toggle(isOn: Binding(
                            get: { configManager.settings.launchAtLogin },
                            set: { newValue in
                                configManager.settings.launchAtLogin = newValue
                                configManager.saveConfig()
                            }
                        )) {
                            Text("Launch at Login")
                        }
                        
                        // Refresh Rate
                        HStack {
                            Text("Refresh Interval")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { configManager.settings.refreshInterval },
                                set: { newValue in
                                    configManager.settings.refreshInterval = newValue
                                    configManager.saveConfig()
                                }
                            )) {
                                Text("Every 30s").tag(Double(30))
                                Text("Every 1 min").tag(Double(60))
                                Text("Every 2 min").tag(Double(120))
                                Text("Every 5 min").tag(Double(300))
                                Text("Manual").tag(Double(0))
                            }
                            .frame(width: 140)
                        }
                        
                        // Notifications toggle
                        Toggle(isOn: Binding(
                            get: { configManager.settings.enableNotifications },
                            set: { newValue in
                                configManager.settings.enableNotifications = newValue
                                configManager.saveConfig()
                                if newValue {
                                    NotificationManager.shared.requestAuthorization()
                                }
                            }
                        )) {
                            Text("Enable Desktop Notifications")
                        }
                        
                        // Notify only starred toggle (conditional)
                        if configManager.settings.enableNotifications {
                            Toggle(isOn: Binding(
                                get: { configManager.settings.notifyOnlyStarred },
                                set: { newValue in
                                    configManager.settings.notifyOnlyStarred = newValue
                                    configManager.saveConfig()
                                }
                            )) {
                                Text("Notify Only for Starred Repositories")
                            }
                            .padding(.leading, 16)
                        }
                    }
                    
                    Divider()
                    
                    // Section 3: Advanced (Custom Client ID)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OAuth Customization")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.secondary)
                        
                        Text("If you prefer not to authorize via the built-in Client ID, you can register your own GitHub OAuth application with 'Device flow' enabled and paste the Client ID below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("Custom GitHub Client ID", text: Binding(
                                get: { configManager.settings.githubClientId },
                                set: { newValue in
                                    configManager.settings.githubClientId = newValue
                                    configManager.saveConfig()
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            
                            if !configManager.settings.githubClientId.isEmpty {
                                Button(action: {
                                    configManager.settings.githubClientId = ""
                                    configManager.saveConfig()
                                }) {
                                    Image(systemName: "multiply.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 4: Account Actions
                    HStack {
                        Spacer()
                        Button(action: {
                            githubService.signOut()
                            NotificationCenter.default.post(name: Notification.Name("CloseSettings"), object: nil)
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out of GitHub")
                            }
                            .bold()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
