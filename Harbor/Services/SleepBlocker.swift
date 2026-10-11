import Foundation
import IOKit
import IOKit.pwr_mgt

/// Keeps the Mac and its display awake, lid open or closed.
///
/// Idle sleep is held off with ordinary power assertions, which the system drops by itself
/// if Harbor exits. Closing the lid ignores assertions, so that part is a separate switch on
/// the power-management root domain. It outlives the process, so `stop()` must run before quitting.
final class SleepBlocker {
    private var assertions: [IOPMAssertionID] = []
    private var powerManagement: io_connect_t = 0

    /// False on desktops, where there's no lid to worry about.
    static let hasLid: Bool = {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        return IORegistryEntryCreateCFProperty(root, kAppleClamshellStateKey as CFString, kCFAllocatorDefault, 0) != nil
    }()

    /// Returns false, holding nothing, if the system refuses.
    func start() -> Bool {
        guard assertions.isEmpty else { return true }
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep] {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Harbor is keeping watch" as CFString,
                &id
            )
            guard result == kIOReturnSuccess else {
                stop()
                return false
            }
            assertions.append(id)
        }
        if Self.hasLid {
            powerManagement = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
            setLidSleepDisabled(true)
        }
        return true
    }

    func stop() {
        assertions.forEach { IOPMAssertionRelease($0) }
        assertions = []
        if powerManagement != 0 {
            setLidSleepDisabled(false)
            IOServiceClose(powerManagement)
            powerManagement = 0
        }
    }

    private func setLidSleepDisabled(_ disabled: Bool) {
        guard powerManagement != 0 else { return }
        var input: [UInt64] = [disabled ? 1 : 0]
        var outputCount: UInt32 = 0
        IOConnectCallScalarMethod(powerManagement, UInt32(kPMSetClamshellSleepState), &input, 1, nil, &outputCount)
    }
}
