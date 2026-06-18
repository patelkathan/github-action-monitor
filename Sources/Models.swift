import Foundation

struct MonitoredRepo: Codable, Identifiable, Hashable {
    var id: String { "\(owner)/\(name)" }
    let owner: String
    let name: String
    var branch: String? // Optional branch filter
    var isStarred: Bool? = false // Optional to support backward compatibility
    
    var fullName: String {
        "\(owner)/\(name)"
    }
    
    var starred: Bool {
        isStarred ?? false
    }
}

struct AppSettings: Codable {
    var refreshInterval: Double = 60.0 // seconds
    var enableNotifications: Bool = true
    var githubClientId: String = "" // Optional custom client ID for Device Flow
    var autoDetectRepos: Bool = true // Smart auto-detection of recently active pipelines
    var launchAtLogin: Bool = false // Auto start app when logging in
    var notifyOnlyStarred: Bool = false // Toggle to only receive notifications for starred repos
}

struct RepoStatusGroup: Identifiable, Equatable, Hashable {
    var id: String { fullName }
    let owner: String
    let name: String
    var fullName: String { "\(owner)/\(name)" }
    var isStarred: Bool = false
    var runs: [WorkflowRun] = []
    var pushedAt: Date?
    
    var latestRun: WorkflowRun? {
        runs.first
    }
    
    static func == (lhs: RepoStatusGroup, rhs: RepoStatusGroup) -> Bool {
        return lhs.fullName == rhs.fullName && lhs.isStarred == rhs.isStarred && lhs.runs == rhs.runs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fullName)
        hasher.combine(isStarred)
    }
}

struct GitHubRepository: Codable {
    let name: String
    let owner: GitHubOwner
    let fullName: String
    let pushedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case owner
        case fullName = "full_name"
        case pushedAt = "pushed_at"
    }
}

struct GitHubOwner: Codable {
    let login: String
}

// GitHub API Models

struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

struct WorkflowRun: Codable, Identifiable, Equatable {
    let id: Int
    let runNumber: Int
    let event: String
    var status: String       // e.g. "queued", "in_progress", "completed"
    var conclusion: String?  // e.g. "success", "failure", "cancelled", "timed_out", nil if running
    let htmlUrl: String
    let createdAt: Date
    var updatedAt: Date
    let displayTitle: String  // Commit message
    let headBranch: String
    let headCommit: HeadCommit?
    
    // We add repoName locally to know which repo this run belongs to
    var repoName: String = ""
    
    enum CodingKeys: String, CodingKey {
        case id
        case runNumber = "run_number"
        case event
        case status
        case conclusion
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case displayTitle = "display_title"
        case headBranch = "head_branch"
        case headCommit = "head_commit"
    }
    
    static func == (lhs: WorkflowRun, rhs: WorkflowRun) -> Bool {
        return lhs.id == rhs.id && lhs.status == rhs.status && lhs.conclusion == rhs.conclusion
    }
}

struct HeadCommit: Codable {
    let id: String
    let message: String
    let author: CommitAuthor?
}

struct CommitAuthor: Codable {
    let name: String
    let email: String?
}

// Device Flow response structs
struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct OAuthTokenResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }
}

struct SharedFormatters {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    static let iso8601: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
    }()
}
