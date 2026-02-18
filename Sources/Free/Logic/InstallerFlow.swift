import Foundation

enum InstallerRunResult: Equatable {
    case cancelled
    case sourceMissing
    case installFailed
    case installed
    case installedLaunchFailed
}

protocol InstallerSystem {
    var appName: String { get }
    var bundleURL: URL { get }

    func fileExists(atPath: String) -> Bool
    func confirmReplaceExistingApp() -> Bool

    func runShellCommand(_ command: String) -> Bool
    func runShellCommandAsAdmin(_ command: String) -> Bool
    func launchInstalledApp(at url: URL) -> String?

    func showAlert(title: String, message: String)
}

struct InstallerFlow {
    private let system: any InstallerSystem

    init(system: any InstallerSystem) {
        self.system = system
    }

    func runInstall() -> InstallerRunResult {
        let sourceURL = sourceAppURL
        let targetURL = targetAppURL

        guard system.fileExists(atPath: sourceURL.path) else {
            system.showAlert(
                title: "Could not find \(system.appName).app",
                message:
                    "Please open Install \(system.appName).app from the disk image that contains \(system.appName).app."
            )
            return .sourceMissing
        }

        if system.fileExists(atPath: targetURL.path), !system.confirmReplaceExistingApp() {
            return .cancelled
        }

        let installCommand = Self.installCommand(sourceURL: sourceURL, targetURL: targetURL)
        if !system.runShellCommand(installCommand), !system.runShellCommandAsAdmin(installCommand) {
            system.showAlert(
                title: "Installation failed",
                message:
                    "\(system.appName) could not be copied to /Applications. Please check permissions and try again."
            )
            return .installFailed
        }

        if let launchError = system.launchInstalledApp(at: targetURL) {
            system.showAlert(
                title: "Installed, but launch failed",
                message:
                    "\(system.appName) was installed to /Applications, but could not be launched automatically.\n\n\(launchError)"
            )
            return .installedLaunchFailed
        }

        return .installed
    }

    var sourceAppURL: URL {
        system.bundleURL.deletingLastPathComponent().appendingPathComponent("\(system.appName).app")
    }

    var targetAppURL: URL {
        URL(fileURLWithPath: "/Applications/\(system.appName).app")
    }

    static func installCommand(sourceURL: URL, targetURL: URL) -> String {
        [
            "/bin/rm -rf \(shellQuote(targetURL.path))",
            "/usr/bin/ditto \(shellQuote(sourceURL.path)) \(shellQuote(targetURL.path))",
            "/usr/bin/xattr -d -r com.apple.quarantine \(shellQuote(targetURL.path)) >/dev/null 2>&1 || true",
        ].joined(separator: "; ")
    }

    static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
