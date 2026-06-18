import os

enum Log {
    static let app = Logger(subsystem: "com.kathanpatel.TrayFlow", category: "app")
    static let auth = Logger(subsystem: "com.kathanpatel.TrayFlow", category: "auth")
    static let network = Logger(subsystem: "com.kathanpatel.TrayFlow", category: "network")
    static let config = Logger(subsystem: "com.kathanpatel.TrayFlow", category: "config")
    static let notifications = Logger(subsystem: "com.kathanpatel.TrayFlow", category: "notifications")
}
