import SwiftUI

struct RepoDetailView: View {
    let repoGroup: RepoStatusGroup
    @ObservedObject var githubService = GitHubService.shared
    @ObservedObject var configManager = ConfigManager.shared
    
    @State private var rerunningIds = Set<Int>()
    @State private var hoverRunId: Int? = nil
    
    // Callback to dismiss
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .bold()
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: []) // ESC key to go back!
                
                Spacer()
                
                Text(repoGroup.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Star button
                    Button(action: {
                        githubService.toggleRepoStar(id: repoGroup.fullName)
                    }) {
                        Image(systemName: configManager.isRepoStarred(id: repoGroup.fullName) ? "star.fill" : "star")
                            .foregroundColor(configManager.isRepoStarred(id: repoGroup.fullName) ? .yellow : .secondary)
                            .font(.system(size: 14))
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(configManager.isRepoStarred(id: repoGroup.fullName) ? "Unstar repository" : "Star repository")
                    
                    // Open in GitHub button
                    Button(action: {
                        if let url = URL(string: "https://github.com/\(repoGroup.fullName)") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "safari")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open repository in browser")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.01))
            
            Divider()
            
            // Repository Overview Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repoGroup.fullName)
                            .font(.title3)
                            .bold()
                        
                        Text("Pushed \(formattedPushedDate())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            
            // Historical Runs
            VStack(alignment: .leading, spacing: 10) {
                Text("Pipeline History")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                if repoGroup.runs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No workflow runs found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(repoGroup.runs) { run in
                                HistoricalRunRow(
                                    run: run,
                                    isHovering: hoverRunId == run.id,
                                    isRerunning: rerunningIds.contains(run.id),
                                    onRerun: {
                                        triggerRerun(for: run)
                                    },
                                    onOpen: {
                                        if let url = URL(string: run.htmlUrl) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                )
                                .onHover { isHovering in
                                    if isHovering {
                                        self.hoverRunId = run.id
                                    } else if self.hoverRunId == run.id {
                                        self.hoverRunId = nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }
    
    private func triggerRerun(for run: WorkflowRun) {
        rerunningIds.insert(run.id)
        Task {
            _ = await githubService.rerunWorkflow(runId: run.id, repoFullName: run.repoName)
            DispatchQueue.main.async {
                rerunningIds.remove(run.id)
            }
        }
    }
    
    private func formattedPushedDate() -> String {
        guard let date = repoGroup.pushedAt else { return "Unknown" }
        return SharedFormatters.relative.localizedString(for: date, relativeTo: Date())
    }
}

// Row component for listing historical runs
struct HistoricalRunRow: View {
    let run: WorkflowRun
    let isHovering: Bool
    let isRerunning: Bool
    let onRerun: () -> Void
    let onOpen: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status LED/badge
            statusIcon(run.status, conclusion: run.conclusion)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(run.displayTitle)
                        .font(.system(.subheadline, design: .rounded))
                        .bold()
                        .lineLimit(1)
                    
                    Spacer()
                    
                    ZStack {
                        if isRerunning {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        } else if isHovering {
                            Button(action: onRerun) {
                                Image(systemName: "arrow.clockwise.circle")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Re-run this pipeline")
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 8))
                        Text(run.headBranch)
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.blue.opacity(0.8))
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text("#\(run.runNumber)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text(timeAgo(run.createdAt))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(isHovering ? 0.8 : 0.4))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(isHovering ? 0.12 : 0.05), lineWidth: 1)
        )
        .onTapGesture(perform: onOpen)
    }
    
    @ViewBuilder
    private func statusIcon(_ status: String, conclusion: String?) -> some View {
        if status == "in_progress" || status == "queued" {
            SpinningProgressIcon(isSpinning: status == "in_progress")
        } else if status == "completed" {
            switch conclusion {
            case "success":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.06, green: 0.64, blue: 0.50))
            case "failure":
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            case "cancelled":
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            default:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        } else {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        return SharedFormatters.relative.localizedString(for: date, relativeTo: Date())
    }
}

// A dedicated helper view to spin the orange progress arrow smoothly.
// By encapsulating state and animation inside this small struct, 
// redraws of parent rows (e.g., due to hover status changes) do not reset or break the rotation.
struct SpinningProgressIcon: View {
    let isSpinning: Bool
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(.orange)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                if isSpinning {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: isSpinning) { newValue in
                if newValue {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                } else {
                    withAnimation(.default) {
                        isAnimating = false
                    }
                }
            }
    }
}
