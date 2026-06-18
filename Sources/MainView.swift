import SwiftUI

struct MainView: View {
    @ObservedObject var githubService = GitHubService.shared
    @ObservedObject var configManager = ConfigManager.shared
    @State private var showSettings = false
    @State private var selectedRepo: RepoStatusGroup? = nil
    
    // Search and Filters
    @State private var searchText = ""
    @State private var selectedFilter: StatusFilter = .all
    @State private var hoverRepoId: String? = nil
    
    // Timer to update "time ago" strings
    @State private var uiRefreshTrigger = false
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case running = "Running"
        case failed = "Failed"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Keyboard Shortcut Hooks
            backgroundShortcuts
            
            if !githubService.isAuthenticated {
                LoginView()
            } else if showSettings {
                SettingsView()
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CloseSettings"))) { _ in
                        self.showSettings = false
                    }
            } else if let repoGroup = selectedRepo {
                // Repository runs detail navigation
                RepoDetailView(repoGroup: repoGroup, onBack: {
                    self.selectedRepo = nil
                    // Fetch latest status when returning
                    Task {
                        await githubService.fetchRuns()
                    }
                })
            } else {
                // Core Dashboard Home View
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TrayFlow")
                                .font(.system(.headline, design: .rounded))
                                .bold()
                            
                            if let lastRefresh = githubService.lastRefreshTime {
                                Text("Updated \(timeAgo(lastRefresh))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Connecting...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            // Refresh Button / Loading Indicator
                            Button(action: {
                                Task {
                                    await githubService.fetchRuns()
                                }
                            }) {
                                ZStack {
                                    if githubService.isRefreshing {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(githubService.isRefreshing)
                            .help("Refresh (⌘R)")
                            
                            // Settings Button
                            Button(action: {
                                self.showSettings = true
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Settings (⌘,)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.01))

                    if let fetchError = githubService.fetchError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(fetchError)
                                .font(.system(size: 10))
                                .lineLimit(2)
                            Spacer()
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                    }

                    Divider()

                    // Search & Filters Header
                    VStack(spacing: 8) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            
                            TextField("Search repositories...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                            
                            if !searchText.isEmpty {
                                Button(action: { self.searchText = "" }) {
                                    Image(systemName: "multiply.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                        .padding(4)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                        
                        // Status Filter Pills
                        HStack(spacing: 8) {
                            ForEach(StatusFilter.allCases) { filter in
                                Button(action: {
                                    self.selectedFilter = filter
                                }) {
                                    Text(filter.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(selectedFilter == filter ? Color.blue : Color.primary.opacity(0.04))
                                        .foregroundColor(selectedFilter == filter ? .white : .secondary)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.01))
                    
                    Divider()
                    
                    // Dashboard Repository list
                    let filteredRepos = getFilteredRepoGroups()
                    
                    if githubService.repoGroups.isEmpty && githubService.isRefreshing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Auto-detecting active pipelines...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 60)
                    } else if filteredRepos.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "bolt.slash" : "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text(searchText.isEmpty ? "No Pipelines Found" : "No Match Found")
                                .font(.headline)
                            Text(searchText.isEmpty 
                                 ? "Pushed repositories will automatically show here once they run a workflow pipeline." 
                                 : "Try adjusting your search query or filters.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredRepos) { group in
                                    RepoDashboardRow(
                                        repoGroup: group,
                                        isHovering: hoverRepoId == group.fullName,
                                        onStarToggle: {
                                            githubService.toggleRepoStar(id: group.fullName)
                                        },
                                        onSelect: {
                                            self.selectedRepo = group
                                        }
                                    )
                                    .onHover { isHovering in
                                        if isHovering {
                                            self.hoverRepoId = group.fullName
                                        } else if self.hoverRepoId == group.fullName {
                                            self.hoverRepoId = nil
                                        }
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                    
                    // Bottom status bar
                    Divider()
                    HStack {
                        Circle()
                            .fill(globalStatusColor())
                            .frame(width: 8, height: 8)
                        Text(globalStatusText())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            NSApplication.shared.terminate(nil)
                        }) {
                            Text("Quit")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.01))
                }
            }
        }
        .frame(width: 340, height: 450)
        .onReceive(timer) { _ in
            self.uiRefreshTrigger.toggle()
        }
    }
    
    // Invisible keyboard shortcut handlers
    private var backgroundShortcuts: some View {
        HStack {
            Button("") {
                Task { await githubService.fetchRuns() }
            }
            .keyboardShortcut("r", modifiers: .command)
            
            Button("") {
                self.showSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .buttonStyle(.plain)
        .frame(width: 0, height: 0)
        .opacity(0)
    }
    
    // Filter helper
    private func getFilteredRepoGroups() -> [RepoStatusGroup] {
        var groups = githubService.repoGroups
        
        // 1. Search Filter
        if !searchText.isEmpty {
            groups = groups.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 2. Status Filter
        switch selectedFilter {
        case .all:
            break
        case .running:
            groups = groups.filter { group in
                if let run = group.latestRun {
                    return run.status == "in_progress" || run.status == "queued"
                }
                return false
            }
        case .failed:
            groups = groups.filter { group in
                if let run = group.latestRun {
                    return run.status == "completed" && run.conclusion == "failure"
                }
                return false
            }
        }
        
        return groups
    }
    
    // Format helpers
    private func timeAgo(_ date: Date) -> String {
        return SharedFormatters.relative.localizedString(for: date, relativeTo: Date())
    }
    
    private func globalStatusColor() -> Color {
        if githubService.isRefreshing {
            return .orange
        }
        let runs = githubService.workflowRuns
        if runs.isEmpty { return .gray }
        
        if runs.contains(where: { $0.status == "completed" && $0.conclusion == "failure" }) {
            return .red
        }
        
        if runs.contains(where: { $0.status == "in_progress" || $0.status == "queued" }) {
            return .yellow
        }
        
        return Color(red: 0.06, green: 0.64, blue: 0.50)
    }
    
    private func globalStatusText() -> String {
        if githubService.isRefreshing {
            return "Refreshing..."
        }
        let runs = githubService.workflowRuns
        if runs.isEmpty { return "No pipelines monitored" }
        
        let failures = runs.filter { $0.status == "completed" && $0.conclusion == "failure" }.count
        let running = runs.filter { $0.status == "in_progress" || $0.status == "queued" }.count
        
        if failures > 0 {
            return "\(failures) pipeline\(failures > 1 ? "s" : "") failing"
        }
        if running > 0 {
            return "\(running) running..."
        }
        return "All systems operational"
    }
}

// Row component for listing repositories on the home page
struct RepoDashboardRow: View {
    let repoGroup: RepoStatusGroup
    let isHovering: Bool
    var onStarToggle: () -> Void
    var onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status LED dot (Left)
            Circle()
                .fill(statusColor(repoGroup.latestRun))
                .frame(width: 8, height: 8)
                .shadow(color: statusColor(repoGroup.latestRun).opacity(0.3), radius: 2)
            
            // Name and detail (Middle)
            VStack(alignment: .leading, spacing: 3) {
                Text(repoGroup.name)
                    .font(.system(.body, design: .rounded))
                    .bold()
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(repoGroup.owner)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text("pushed \(timeAgo())")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Interaction icons (Right)
            HStack(spacing: 8) {
                // Star Button (Visible if starred, or if hovering)
                if repoGroup.isStarred || isHovering {
                    Button(action: onStarToggle) {
                        Image(systemName: repoGroup.isStarred ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(repoGroup.isStarred ? .yellow : .secondary)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // Chevron right to details
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(isHovering ? 0.8 : 0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(isHovering ? 0.12 : 0.05), lineWidth: 1)
        )
        .onTapGesture(perform: onSelect)
    }
    
    private func statusColor(_ run: WorkflowRun?) -> Color {
        guard let run = run else { return .gray }
        
        if run.status == "in_progress" || run.status == "queued" {
            return .orange
        }
        
        switch run.conclusion {
        case "success":
            return Color(red: 0.06, green: 0.64, blue: 0.50)
        case "failure":
            return .red
        case "cancelled":
            return .gray
        default:
            return .secondary
        }
    }
    
    private func timeAgo() -> String {
        guard let date = repoGroup.pushedAt else { return "recently" }
        return SharedFormatters.relative.localizedString(for: date, relativeTo: Date())
    }
}
