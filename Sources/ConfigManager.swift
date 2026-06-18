import Foundation
import ServiceManagement

final class ConfigManager: ObservableObject, @unchecked Sendable {
    @Published var monitoredRepos: [MonitoredRepo] = []
    @Published var settings: AppSettings = AppSettings()
    
    static let shared = ConfigManager()
    
    private var configURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("TrayFlow", isDirectory: true)
        
        // Ensure folder exists
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        
        return appDirectory.appendingPathComponent("config.json")
    }
    
    private init() {
        loadConfig()
    }
    
    func loadConfig() {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Default repos for initial setup
            self.monitoredRepos = [
                MonitoredRepo(owner: "kathanpatel", name: "github-action-monitor", branch: nil, isStarred: false)
            ]
            self.settings = AppSettings()
            saveConfig()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            struct ConfigContainer: Codable {
                let repos: [MonitoredRepo]
                let settings: AppSettings
            }
            
            let container = try decoder.decode(ConfigContainer.self, from: data)
            self.monitoredRepos = container.repos
            self.settings = container.settings
        } catch {
            Log.config.error("Error loading config: \(error.localizedDescription, privacy: .public)")
            // Fallback default
            self.monitoredRepos = []
            self.settings = AppSettings()
        }
    }
    
    func saveConfig() {
        do {
            struct ConfigContainer: Codable {
                let repos: [MonitoredRepo]
                let settings: AppSettings
            }
            let container = ConfigContainer(repos: monitoredRepos, settings: settings)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(container)
            try data.write(to: configURL, options: .atomic)

            // Apply Launch at Login state
            updateLaunchAtLoginState()

            // Post notification that config changed
            NotificationCenter.default.post(name: Notification.Name("ConfigChanged"), object: nil)
        } catch {
            Log.config.error("Error saving config: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func addRepo(owner: String, name: String, branch: String? = nil) {
        let cleanOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalBranch = (cleanBranch == nil || cleanBranch!.isEmpty) ? nil : cleanBranch
        
        let repo = MonitoredRepo(owner: cleanOwner, name: cleanName, branch: finalBranch, isStarred: false)
        
        if !monitoredRepos.contains(where: { $0.id == repo.id && $0.branch == repo.branch }) {
            monitoredRepos.append(repo)
            saveConfig()
        }
    }
    
    func removeRepo(id: String) {
        monitoredRepos.removeAll { $0.id == id }
        saveConfig()
    }
    
    func toggleStar(id: String) {
        if let index = monitoredRepos.firstIndex(where: { $0.id == id }) {
            let current = monitoredRepos[index].isStarred ?? false
            monitoredRepos[index].isStarred = !current
            saveConfig()
        } else {
            // Star an auto-detected repo (automatically saves it explicitly)
            let parts = id.split(separator: "/")
            if parts.count == 2 {
                let owner = String(parts[0])
                let name = String(parts[1])
                let repo = MonitoredRepo(owner: owner, name: name, branch: nil, isStarred: true)
                monitoredRepos.append(repo)
                saveConfig()
            }
        }
    }
    
    func isRepoStarred(id: String) -> Bool {
        if let repo = monitoredRepos.first(where: { $0.id == id }) {
            return repo.starred
        }
        return false
    }
    
    private func updateLaunchAtLoginState() {
        let service = SMAppService.mainApp
        if settings.launchAtLogin {
            if service.status != .enabled {
                do {
                    try service.register()
                    Log.config.info("SMAppService registered successfully.")
                } catch {
                    Log.config.error("Failed to register SMAppService: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else {
            if service.status == .enabled {
                do {
                    try service.unregister()
                    Log.config.info("SMAppService unregistered successfully.")
                } catch {
                    Log.config.error("Failed to unregister SMAppService: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
