#if os(macOS)
import AppKit
import Foundation
import RazerCore

@MainActor
final class LightingAnimationController {
    private struct ActiveRipple {
        let origin: MatrixPoint
        let startedAt: Date
    }

    private let transport: HIDTransport
    private let onFailure: (String) -> Void
    private var animationTask: Task<Void, Never>?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var activeRipples: [ActiveRipple] = []

    init(
        transport: HIDTransport,
        onFailure: @escaping (String) -> Void
    ) {
        self.transport = transport
        self.onFailure = onFailure
    }

    func start(
        effect: LightingEffect,
        target: LightingTarget,
        on device: RazerDevice
    ) async throws {
        stop()
        guard
            let lightingProtocol = device.lightingProtocol,
            let dimensions = DeviceMatrixLayout.dimensions(for: device)
        else {
            throw RazerProtocolError.unsupportedEffect(
                effect: effect.kind,
                lightingProtocol: device.lightingProtocol ?? .standardMatrix
            )
        }

        let customMode = try RazerCommands.lighting(
            effect,
            target: target,
            transactionID: device.transactionID,
            protocol: lightingProtocol
        )
        _ = try await transport.send(customMode, to: device)

        switch effect {
        case .wheel:
            let initialFrame = MatrixAnimations.wheelFrame(
                rows: dimensions.rows,
                columns: dimensions.columns,
                phase: 0
            )
            try await send(initialFrame, to: device, protocol: lightingProtocol)
            animationTask = Task { [weak self] in
                await self?.runWheel(
                    dimensions: dimensions,
                    device: device,
                    protocol: lightingProtocol
                )
            }
        case .ripple(let colour):
            installKeyMonitors(dimensions: dimensions)
            try await send(
                blankFrame(dimensions),
                to: device,
                protocol: lightingProtocol
            )
            animationTask = Task { [weak self] in
                await self?.runRipple(
                    colour: colour,
                    dimensions: dimensions,
                    device: device,
                    protocol: lightingProtocol
                )
            }
        default:
            break
        }
    }

    func stop() {
        animationTask?.cancel()
        animationTask = nil
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        globalKeyMonitor = nil
        localKeyMonitor = nil
        activeRipples.removeAll()
    }

    private func runWheel(
        dimensions: LightingMatrixDimensions,
        device: RazerDevice,
        protocol lightingProtocol: LightingProtocol
    ) async {
        var phase = 0.025
        while !Task.isCancelled {
            do {
                let frame = MatrixAnimations.wheelFrame(
                    rows: dimensions.rows,
                    columns: dimensions.columns,
                    phase: phase
                )
                try await send(frame, to: device, protocol: lightingProtocol)
                phase = (phase + 0.025).truncatingRemainder(dividingBy: 1)
                try await Task.sleep(for: .milliseconds(50))
            } catch is CancellationError {
                return
            } catch {
                stopAfterFailure(error)
                return
            }
        }
    }

    private func runRipple(
        colour: RazerCore.RGBColor,
        dimensions: LightingMatrixDimensions,
        device: RazerDevice,
        protocol lightingProtocol: LightingProtocol
    ) async {
        let duration = 1.1
        while !Task.isCancelled {
            let now = Date()
            activeRipples.removeAll {
                now.timeIntervalSince($0.startedAt) >= duration
            }
            guard !activeRipples.isEmpty else {
                do {
                    try await Task.sleep(for: .milliseconds(30))
                    continue
                } catch {
                    return
                }
            }

            let ripples = activeRipples.map {
                MatrixRipple(
                    origin: $0.origin,
                    progress: now.timeIntervalSince($0.startedAt) / duration
                )
            }
            do {
                let frame = MatrixAnimations.rippleFrame(
                    rows: dimensions.rows,
                    columns: dimensions.columns,
                    ripples: ripples,
                    colour: colour
                )
                try await send(frame, to: device, protocol: lightingProtocol)
                try await Task.sleep(for: .milliseconds(30))
            } catch is CancellationError {
                return
            } catch {
                stopAfterFailure(error)
                return
            }
        }
    }

    private func send(
        _ frame: [[RazerCore.RGBColor]],
        to device: RazerDevice,
        protocol lightingProtocol: LightingProtocol
    ) async throws {
        for (rowIndex, row) in frame.enumerated() {
            for start in stride(from: 0, to: row.count, by: 22) {
                let end = min(start + 22, row.count)
                let command = try RazerCommands.customFrameRow(
                    Array(row[start..<end]),
                    row: UInt8(rowIndex),
                    startColumn: UInt8(start),
                    transactionID: device.transactionID,
                    protocol: lightingProtocol
                )
                _ = try await transport.send(command, to: device)
            }
        }
    }

    private func installKeyMonitors(dimensions: LightingMatrixDimensions) {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            self?.addRipple(for: event.keyCode, dimensions: dimensions)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            self?.addRipple(for: event.keyCode, dimensions: dimensions)
            return event
        }
    }

    private func addRipple(
        for keyCode: UInt16,
        dimensions: LightingMatrixDimensions
    ) {
        activeRipples.append(
            .init(
                origin: KeyboardMatrixKeyMap.point(
                    for: keyCode,
                    dimensions: dimensions
                ),
                startedAt: Date()
            )
        )
        if activeRipples.count > 12 {
            activeRipples.removeFirst(activeRipples.count - 12)
        }
    }

    private func blankFrame(
        _ dimensions: LightingMatrixDimensions
    ) -> [[RazerCore.RGBColor]] {
        Array(
            repeating: Array(
                repeating: RazerCore.RGBColor(red: 0, green: 0, blue: 0),
                count: dimensions.columns
            ),
            count: dimensions.rows
        )
    }

    private func stopAfterFailure(_ error: Error) {
        stop()
        onFailure(error.localizedDescription)
    }
}

enum KeyboardMatrixKeyMap {
    static func point(
        for keyCode: UInt16,
        dimensions: LightingMatrixDimensions
    ) -> MatrixPoint {
        let standard = ansiPositions[keyCode] ?? MatrixPoint(row: 3, column: 11)
        let row = scaled(standard.row, from: 6, to: dimensions.rows)
        let column = scaled(standard.column, from: 22, to: dimensions.columns)
        return MatrixPoint(row: row, column: column)
    }

    private static func scaled(_ value: Int, from source: Int, to destination: Int) -> Int {
        guard destination > 1 else {
            return 0
        }
        return min(
            destination - 1,
            Int((Double(value) / Double(source - 1) * Double(destination - 1)).rounded())
        )
    }

    private static let ansiPositions: [UInt16: MatrixPoint] = [
        53: .init(row: 0, column: 1),
        50: .init(row: 1, column: 1),
        18: .init(row: 1, column: 2),
        19: .init(row: 1, column: 3),
        20: .init(row: 1, column: 4),
        21: .init(row: 1, column: 5),
        23: .init(row: 1, column: 6),
        22: .init(row: 1, column: 7),
        26: .init(row: 1, column: 8),
        28: .init(row: 1, column: 9),
        25: .init(row: 1, column: 10),
        29: .init(row: 1, column: 11),
        27: .init(row: 1, column: 12),
        24: .init(row: 1, column: 13),
        51: .init(row: 1, column: 15),
        12: .init(row: 2, column: 2),
        13: .init(row: 2, column: 3),
        14: .init(row: 2, column: 4),
        15: .init(row: 2, column: 5),
        17: .init(row: 2, column: 6),
        16: .init(row: 2, column: 7),
        32: .init(row: 2, column: 8),
        34: .init(row: 2, column: 9),
        31: .init(row: 2, column: 10),
        35: .init(row: 2, column: 11),
        33: .init(row: 2, column: 12),
        30: .init(row: 2, column: 13),
        0: .init(row: 3, column: 2),
        1: .init(row: 3, column: 3),
        2: .init(row: 3, column: 4),
        3: .init(row: 3, column: 5),
        5: .init(row: 3, column: 6),
        4: .init(row: 3, column: 7),
        38: .init(row: 3, column: 8),
        40: .init(row: 3, column: 9),
        37: .init(row: 3, column: 10),
        41: .init(row: 3, column: 11),
        39: .init(row: 3, column: 12),
        6: .init(row: 4, column: 3),
        7: .init(row: 4, column: 4),
        8: .init(row: 4, column: 5),
        9: .init(row: 4, column: 6),
        11: .init(row: 4, column: 7),
        45: .init(row: 4, column: 8),
        46: .init(row: 4, column: 9),
        43: .init(row: 4, column: 10),
        47: .init(row: 4, column: 11),
        44: .init(row: 4, column: 12),
        49: .init(row: 5, column: 7),
        123: .init(row: 5, column: 15),
        126: .init(row: 4, column: 16),
        125: .init(row: 5, column: 16),
        124: .init(row: 5, column: 17)
    ]
}
#endif
