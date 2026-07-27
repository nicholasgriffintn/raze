#if os(macOS)
import AppKit
import Foundation
import IOKit.ps
import RazerCore

@MainActor
final class SystemEventMonitor {
    private let onEvent: (AutomationEvent) -> Void
    private var workspaceObservers: [NSObjectProtocol] = []
    private var powerObserver: NSObjectProtocol?
    private var lastPowerSource: AutomationEvent?

    init(onEvent: @escaping (AutomationEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        guard workspaceObservers.isEmpty, powerObserver == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        observe(NSWorkspace.didWakeNotification, as: .wake, in: center)
        observe(NSWorkspace.willSleepNotification, as: .sleep, in: center)
        observe(
            NSWorkspace.sessionDidResignActiveNotification,
            as: .screenLock,
            in: center
        )
        observe(
            NSWorkspace.sessionDidBecomeActiveNotification,
            as: .screenUnlock,
            in: center
        )

        lastPowerSource = currentPowerEvent()
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.powerSourceChanged() }
        }
    }

    func stop() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
        workspaceObservers.removeAll()
        if let powerObserver {
            NotificationCenter.default.removeObserver(powerObserver)
            self.powerObserver = nil
        }
    }

    private func observe(
        _ notification: Notification.Name,
        as event: AutomationEvent,
        in center: NotificationCenter
    ) {
        workspaceObservers.append(
            center.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onEvent(event) }
            }
        )
    }

    private func powerSourceChanged() {
        guard let event = currentPowerEvent(), event != lastPowerSource else { return }
        lastPowerSource = event
        onEvent(event)
    }

    private func currentPowerEvent() -> AutomationEvent? {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
        else {
            return nil
        }
        return source == kIOPSACPowerValue as CFString ? .acPower : .batteryPower
    }
}
#endif
