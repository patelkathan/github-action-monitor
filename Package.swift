// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrayFlow",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TrayFlow",
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
