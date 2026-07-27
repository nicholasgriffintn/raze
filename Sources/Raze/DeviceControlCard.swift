#if os(macOS)
import RazerCore
import SwiftUI

struct DeviceControlCard: View {
    @EnvironmentObject private var model: AppModel
    let device: RazerDevice

    private var capabilities: DeviceControlCapabilities {
        device.controlCapabilities
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
            }

            if capabilities.supportsBattery {
                BatteryStatusRow(status: model.powerStatus)
            }

            if let dpiRange = capabilities.dpiRange {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text("\(Int(model.dpi)) DPI")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $model.dpi,
                        in: Double(dpiRange.lowerBound)...Double(dpiRange.upperBound),
                        step: 100
                    )
                    .accessibilityLabel("Sensitivity")
                    .accessibilityValue("\(Int(model.dpi)) DPI")
                }
            }

            if !capabilities.pollingRates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Polling rate")
                    Picker("Polling rate", selection: $model.pollingRate) {
                        ForEach(capabilities.pollingRates, id: \.self) { rate in
                            Text("\(rate.rawValue) Hz").tag(rate)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            HStack {
                Spacer()
                Button {
                    Task { await model.applyDeviceControls() }
                } label: {
                    Label("Apply performance", systemImage: "speedometer")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
            }
        }
        .padding(18)
        .controlCard()
    }
}

private struct BatteryStatusRow: View {
    let status: DevicePowerStatus?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: batteryIcon)
                .font(.title3)
                .foregroundStyle(batteryColour)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Battery")
                    .font(.callout.weight(.medium))
                Text(status?.isCharging == true ? "Charging" : "Wireless power")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(status.map { "\($0.percentage)%" } ?? "Unavailable")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(status == nil ? Color.secondary : batteryColour)
        }
        .padding(12)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var batteryIcon: String {
        guard let status else {
            return "battery.0percent"
        }
        if status.isCharging {
            return "battery.100percent.bolt"
        }
        return switch status.percentage {
        case ...10: "battery.0percent"
        case ...35: "battery.25percent"
        case ...65: "battery.50percent"
        case ...90: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private var batteryColour: Color {
        guard let status else {
            return .secondary
        }
        return status.percentage <= 20 ? .orange : .green
    }

    private var accessibilityDescription: String {
        guard let status else {
            return "Battery status unavailable"
        }
        return status.isCharging
            ? "Battery \(status.percentage) percent, charging"
            : "Battery \(status.percentage) percent"
    }
}
#endif
