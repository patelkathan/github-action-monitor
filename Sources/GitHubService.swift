import Foundation
import Combine
import AppKit

final class GitHubService: ObservableObject, @unchecked Sendable {
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var deviceCodeResponse: DeviceCodeResponse?
    @Published var workflowRuns: [WorkflowRun] = []
    @Published var repoGroups: [RepoStatusGroup] = []
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    @Published var authError: String?
    @Published var fetchError: String?

    static let shared = GitHubService()

    // Default GitHub CLI Client ID (supports 'repo' and 'workflow' scopes)
    private static let defaultClientId = "178c6fc778ccc68e1d6a"

    private var deviceFlowTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private init() {
        checkAuthentication()
        setupConfigObserver()
        startAutoRefresh()
    }

    func checkAuthentication() {
        if let token = KeychainHelper.getToken(), !token.isEmpty {
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
    }

    func getEffectiveClientId() -> String {
        let customId = ConfigManager.shared.settings.githubClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        return customId.isEmpty ? Self.defaultClientId : customId
    }

    func signOut() {
        KeychainHelper.deleteToken()
        self.isAuthenticated = false
        self.workflowRuns = []
        self.repoGroups = []
        self.deviceCodeResponse = nil
        self.authError = nil
        self.fetchError = nil
        self.isAuthenticating = false
        deviceFlowTask?.cancel()
        deviceFlowTask = nil
    }

    func toggleRepoStar(id: String) {
        // Toggle in config manager (persists changes)
        ConfigManager.shared.toggleStar(id: id)

        // Instantly update the local memory array
        if let index = repoGroups.firstIndex(where: { $0.fullName == id }) {
            repoGroups[index].isStarred.toggle()

            // Re-sort the local array instantly so the UI reflects it
            repoGroups.sort {
                if $0.isStarred != $1.isStarred {
                    return $0.isStarred && !$1.isStarred
                }
                return ($0.pushedAt ?? Date(timeIntervalSince1970: 0)) > ($1.pushedAt ?? Date(timeIntervalSince1970: 0))
            }
        }
    }

    // MARK: - HTTP helpers

    private func urlEncodedBody(from parameters: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.query?.data(using: .utf8)
    }

    private func authorizedRequest(url: URL, token: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    private func isRateLimited(_ response: HTTPURLResponse) -> Bool {
        if response.statusCode == 429 { return true }
        if response.statusCode == 403,
           let remaining = response.value(forHTTPHeaderField: "x-ratelimit-remaining"),
           remaining == "0" {
            return true
        }
        return false
    }

    // MARK: - Device Flow OAuth

    func startDeviceFlow() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil
        deviceCodeResponse = nil

        deviceFlowTask?.cancel()
        deviceFlowTask = Task { [weak self] in
            await self?.runDeviceFlow()
        }
    }

    private func runDeviceFlow() async {
        let clientId = getEffectiveClientId()
        guard let url = URL(string: "https://github.com/login/device/code") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = urlEncodedBody(from: [
            "client_id": clientId,
            "scope": "repo workflow"
        ])

        let response: DeviceCodeResponse
        do {
            let (data, _) = try await session.data(for: request)
            response = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        } catch {
            Log.auth.error("Failed to start device flow: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                self.authError = "Failed to start GitHub Sign In: \(error.localizedDescription)"
                self.isAuthenticating = false
            }
            return
        }

        await MainActor.run {
            self.deviceCodeResponse = response
        }

        await pollDeviceToken(deviceCode: response.deviceCode, interval: response.interval, expiresIn: response.expiresIn)
    }

    private func pollDeviceToken(deviceCode: String, interval: Int, expiresIn: Int) async {
        let clientId = getEffectiveClientId()
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else { return }

        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        var currentInterval = interval

        while !Task.isCancelled {
            if Date() >= deadline {
                await MainActor.run {
                    self.authError = "Verification code expired. Please try signing in again."
                    self.isAuthenticating = false
                    self.deviceCodeResponse = nil
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = urlEncodedBody(from: [
                "client_id": clientId,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ])

            do {
                let (data, _) = try await session.data(for: request)
                let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)

                if let token = tokenResponse.accessToken {
                    let saved = KeychainHelper.saveToken(token)
                    await MainActor.run {
                        self.isAuthenticating = false
                        self.deviceCodeResponse = nil
                        if saved {
                            self.isAuthenticated = true
                            self.authError = nil
                        } else {
                            self.authError = "Failed to save token to Keychain."
                        }
                    }
                    if saved {
                        await fetchRuns()
                    }
                    return
                } else if let error = tokenResponse.error {
                    switch error {
                    case "authorization_pending":
                        break // poll again after interval
                    case "slow_down":
                        currentInterval += 5
                        Log.auth.info("Received slow_down, increasing poll interval to \(currentInterval)")
                    default:
                        await MainActor.run {
                            self.authError = tokenResponse.errorDescription ?? "Sign-in failed: \(error)"
                            self.isAuthenticating = false
                            self.deviceCodeResponse = nil
                        }
                        return
                    }
                }
            } catch {
                Log.auth.error("Device token poll failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.authError = "Network error: \(error.localizedDescription)"
                    self.isAuthenticating = false
                }
                return
            }

            try? await Task.sleep(nanoseconds: UInt64(currentInterval) * 1_000_000_000)
        }
    }

    // MARK: - GitHub Actions Data Fetching

    private struct RepoFetchResult {
        let repo: MonitoredRepo
        var runs: [WorkflowRun] = []
        var latestDate: Date?
        var unauthorized = false
        var rateLimited = false
    }

    func fetchRuns() async {
        let canStart: Bool = await MainActor.run {
            guard isAuthenticated, !isRefreshing else { return false }
            isRefreshing = true
            return true
        }
        guard canStart else { return }

        guard let token = KeychainHelper.getToken() else {
            await MainActor.run {
                self.isAuthenticated = false
                self.isRefreshing = false
            }
            return
        }

        var reposToFetch = ConfigManager.shared.monitoredRepos
        var recentReposDict: [String: Date] = [:]
        var autoDetectFailed = false

        if ConfigManager.shared.settings.autoDetectRepos {
            do {
                let recentRepos = try await fetchRecentRepos(token: token)
                let isoFormatter = SharedFormatters.iso8601
                for userRepo in recentRepos {
                    let starred = ConfigManager.shared.isRepoStarred(id: userRepo.fullName)
                    let repo = MonitoredRepo(owner: userRepo.owner.login, name: userRepo.name, branch: nil, isStarred: starred)
                    if !reposToFetch.contains(where: { $0.id == repo.id }) {
                        reposToFetch.append(repo)
                    }
                    if let pushStr = userRepo.pushedAt, let date = isoFormatter.date(from: pushStr) {
                        recentReposDict[userRepo.fullName] = date
                    }
                }
            } catch {
                Log.network.error("Failed to auto-detect repositories: \(error.localizedDescription, privacy: .public)")
                autoDetectFailed = true
            }
        }

        guard !reposToFetch.isEmpty else {
            let didFailAutoDetect = autoDetectFailed
            await MainActor.run {
                self.workflowRuns = []
                self.repoGroups = []
                self.isRefreshing = false
                self.lastRefreshTime = Date()
                self.fetchError = didFailAutoDetect ? "Couldn't reach GitHub to auto-detect repositories." : nil
            }
            return
        }

        var newGroups: [RepoStatusGroup] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var anyUnauthorized = false
        var anyRateLimited = false

        await withTaskGroup(of: RepoFetchResult.self) { group in
            for repo in reposToFetch {
                group.addTask {
                    var result = RepoFetchResult(repo: repo)
                    let urlString = "https://api.github.com/repos/\(repo.owner)/\(repo.name)/actions/runs?per_page=10"
                    guard let url = URL(string: urlString) else { return result }

                    let request = self.authorizedRequest(url: url, token: token)

                    do {
                        let (data, response) = try await self.session.data(for: request)
                        guard let httpResponse = response as? HTTPURLResponse else { return result }

                        if httpResponse.statusCode == 401 {
                            result.unauthorized = true
                            return result
                        }
                        if self.isRateLimited(httpResponse) {
                            result.rateLimited = true
                            return result
                        }
                        guard httpResponse.statusCode == 200 else {
                            Log.network.warning("Unexpected status \(httpResponse.statusCode) for \(repo.fullName, privacy: .public)")
                            return result
                        }

                        let runsResponse = try decoder.decode(WorkflowRunsResponse.self, from: data)
                        var runs = runsResponse.workflowRuns.map { run -> WorkflowRun in
                            var r = run
                            r.repoName = repo.fullName
                            return r
                        }

                        if let branch = repo.branch, !branch.isEmpty {
                            runs = runs.filter { $0.headBranch == branch }
                        }

                        result.runs = runs
                        result.latestDate = runs.first?.updatedAt
                    } catch {
                        Log.network.error("Error fetching runs for \(repo.fullName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                    return result
                }
            }

            for await result in group {
                if result.unauthorized { anyUnauthorized = true }
                if result.rateLimited { anyRateLimited = true }

                let isStarred = ConfigManager.shared.isRepoStarred(id: result.repo.id)
                let pushDate = recentReposDict[result.repo.id] ?? result.latestDate ?? Date(timeIntervalSince1970: 0)

                let groupItem = RepoStatusGroup(
                    owner: result.repo.owner,
                    name: result.repo.name,
                    isStarred: isStarred,
                    runs: result.runs,
                    pushedAt: pushDate
                )
                newGroups.append(groupItem)
            }
        }

        if anyUnauthorized {
            await MainActor.run { self.signOut() }
            return
        }

        newGroups.sort {
            if $0.isStarred != $1.isStarred {
                return $0.isStarred && !$1.isStarred
            }
            return ($0.pushedAt ?? Date(timeIntervalSince1970: 0)) > ($1.pushedAt ?? Date(timeIntervalSince1970: 0))
        }

        let allRuns = newGroups.flatMap { $0.runs }
        let finalGroups = newGroups
        let didHitRateLimit = anyRateLimited
        let didFailAutoDetect = autoDetectFailed

        await MainActor.run {
            self.checkForStatusChanges(oldGroups: self.repoGroups, newGroups: finalGroups)
            self.repoGroups = finalGroups
            self.workflowRuns = allRuns
            self.isRefreshing = false
            self.lastRefreshTime = Date()
            if didHitRateLimit {
                self.fetchError = "GitHub API rate limit reached — some pipelines may be stale. Will retry automatically."
            } else if didFailAutoDetect {
                self.fetchError = "Couldn't reach GitHub to auto-detect repositories."
            } else {
                self.fetchError = nil
            }
        }
    }

    private func fetchRecentRepos(token: String) async throws -> [GitHubRepository] {
        guard let url = URL(string: "https://api.github.com/user/repos?sort=pushed&per_page=15") else {
            return []
        }

        let request = authorizedRequest(url: url, token: token)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([GitHubRepository].self, from: data)
    }

    private func checkForStatusChanges(oldGroups: [RepoStatusGroup], newGroups: [RepoStatusGroup]) {
        guard ConfigManager.shared.settings.enableNotifications else { return }

        let oldRuns = oldGroups.flatMap { $0.runs }
        let newRuns = newGroups.flatMap { $0.runs }

        for newRun in newRuns {
            guard newRun.status == "completed", let conclusion = newRun.conclusion else { continue }

            if ConfigManager.shared.settings.notifyOnlyStarred {
                let isStarred = ConfigManager.shared.isRepoStarred(id: newRun.repoName)
                guard isStarred else { continue }
            }

            if let oldRun = oldRuns.first(where: { $0.id == newRun.id }) {
                if oldRun.status != "completed" {
                    triggerStatusNotification(run: newRun, conclusion: conclusion)
                }
            } else {
                if Date().timeIntervalSince(newRun.updatedAt) < 600 {
                    triggerStatusNotification(run: newRun, conclusion: conclusion)
                }
            }
        }
    }

    private func triggerStatusNotification(run: WorkflowRun, conclusion: String) {
        let isSuccess = conclusion == "success"
        let title = isSuccess ? "Pipeline Succeeded" : "Pipeline Failed (\(conclusion))"
        let body = "[\(run.repoName)] \(run.displayTitle) (\(run.headBranch))"

        NotificationManager.shared.sendNotification(title: title, body: body, isSuccess: isSuccess)
    }

    func rerunWorkflow(runId: Int, repoFullName: String) async -> Bool {
        guard let token = KeychainHelper.getToken() else { return false }

        let urlString = "https://api.github.com/repos/\(repoFullName)/actions/runs/\(runId)/rerun"
        guard let url = URL(string: urlString) else { return false }

        let request = authorizedRequest(url: url, token: token, method: "POST")

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }

            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.updateLocalRunStatus(runId: runId, status: "queued", conclusion: nil)
                }

                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    await fetchRuns()
                }
                return true
            } else {
                Log.network.warning("Failed to re-run workflow \(runId): status \(httpResponse.statusCode)")
                return false
            }
        } catch {
            Log.network.error("Failed to re-run workflow \(runId): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // Helper to instantly update run status in local arrays for responsive UI feedback
    private func updateLocalRunStatus(runId: Int, status: String, conclusion: String?) {
        for idx in 0..<self.workflowRuns.count {
            if self.workflowRuns[idx].id == runId {
                self.workflowRuns[idx].status = status
                self.workflowRuns[idx].conclusion = conclusion
                self.workflowRuns[idx].updatedAt = Date()
            }
        }

        for gIdx in 0..<self.repoGroups.count {
            for rIdx in 0..<self.repoGroups[gIdx].runs.count {
                if self.repoGroups[gIdx].runs[rIdx].id == runId {
                    self.repoGroups[gIdx].runs[rIdx].status = status
                    self.repoGroups[gIdx].runs[rIdx].conclusion = conclusion
                    self.repoGroups[gIdx].runs[rIdx].updatedAt = Date()
                }
            }
        }
    }

    // MARK: - Auto Refresh Scheduling

    private func setupConfigObserver() {
        NotificationCenter.default.publisher(for: Notification.Name("ConfigChanged"))
            .sink { [weak self] _ in
                self?.startAutoRefresh()
            }
            .store(in: &cancellables)
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()

        let interval = ConfigManager.shared.settings.refreshInterval
        guard interval > 0 else { return } // 0 means manual refresh

        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchRuns()
            }
        }
    }
}
