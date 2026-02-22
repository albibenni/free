import ServiceManagement

protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    func enable() throws
    func disable() throws
}

struct DefaultLaunchAtLoginManager: LaunchAtLoginManaging {
    struct Runtime {
        var status: () -> SMAppService.Status
        var register: () throws -> Void
        var unregister: () throws -> Void

        static var live: Runtime {
            Runtime(
                status: { SMAppService.mainApp.status },
                register: { try SMAppService.mainApp.register() },
                unregister: { try SMAppService.mainApp.unregister() }
            )
        }
    }

    private let runtime: Runtime

    init(runtime: Runtime = .live) {
        self.runtime = runtime
    }

    var isEnabled: Bool {
        runtime.status() == .enabled
    }

    func enable() throws {
        try runtime.register()
    }

    func disable() throws {
        try runtime.unregister()
    }
}
