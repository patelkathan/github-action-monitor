import SwiftUI

@main
struct TrayFlowApp: App {
    @ObservedObject var githubService = GitHubService.shared
    
    // Hide Dock Icon on launch (double-check since we also set it in Info.plist)
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            MainView()
        } label: {
            HStack {
                Image(systemName: getMenuBarIconName())
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private func getMenuBarIconName() -> String {
        if !githubService.isAuthenticated {
            return "bolt.slash.fill"
        }
        
        if githubService.isRefreshing && githubService.workflowRuns.isEmpty {
            return "arrow.clockwise"
        }
        
        let runs = githubService.workflowRuns
        if runs.isEmpty {
            return "bolt.circle"
        }
        
        // Check for failures
        if runs.contains(where: { $0.status == "completed" && $0.conclusion == "failure" }) {
            return "exclamationmark.triangle.fill"
        }
        
        // Check if building
        if runs.contains(where: { $0.status == "in_progress" || $0.status == "queued" }) {
            return "bolt.horizontal.fill"
        }
        
        // All green
        return "bolt.fill"
    }
}
