import AppKit
import ServiceManagement

protocol LoginItemService: AnyObject {
    var isEnabled: Bool { get }
    var requiresApproval: Bool { get }
    func register() throws
    func unregister() throws
    func openApprovalSettings()
}

final class MainAppLoginItem: LoginItemService {
    private var service: SMAppService { .mainApp }

    var isEnabled: Bool { service.status == .enabled }
    var requiresApproval: Bool { service.status == .requiresApproval }

    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
    func openApprovalSettings() { SMAppService.openSystemSettingsLoginItems() }
}
