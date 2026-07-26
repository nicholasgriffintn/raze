#if os(macOS)
import AppKit
import RazerCore
import SwiftUI

extension DeviceKind {
    var systemImage: String {
        switch self {
        case .mouse: "computermouse"
        case .keyboard, .laptop: "keyboard"
        case .headset: "headphones"
        case .accessory: "lightbulb.led"
        case .unknown: "questionmark.circle"
        }
    }
}

extension LightingTarget {
    var displayName: String {
        switch self {
        case .all: "All lighting"
        case .scrollWheel: "Scroll wheel"
        case .battery: "Battery"
        case .logo: "Logo"
        case .backlight: "Backlight"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "circle.grid.cross"
        case .scrollWheel: "scroll"
        case .battery: "battery.75percent"
        case .logo: "seal"
        case .backlight: "lightbulb.led"
        }
    }
}

extension LightingEffectKind {
    var displayName: String {
        switch self {
        case .off: "Off"
        case .spectrum: "Spectrum"
        case .staticColor: "Static"
        case .breathing: "Breathing"
        case .reactive: "Reactive"
        case .wave: "Wave"
        }
    }

    var usesColour: Bool {
        switch self {
        case .staticColor, .breathing, .reactive:
            true
        case .off, .spectrum, .wave:
            false
        }
    }
}

extension View {
    func controlCard() -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
    }
}

extension Color {
    init(razerColor: RazerCore.RGBColor) {
        self.init(
            red: Double(razerColor.red) / 255,
            green: Double(razerColor.green) / 255,
            blue: Double(razerColor.blue) / 255
        )
    }

    var razerRGB: RazerCore.RGBColor {
        let converted = NSColor(self).usingColorSpace(.deviceRGB) ?? .green
        return .init(
            red: UInt8(clamping: Int((converted.redComponent * 255).rounded())),
            green: UInt8(clamping: Int((converted.greenComponent * 255).rounded())),
            blue: UInt8(clamping: Int((converted.blueComponent * 255).rounded()))
        )
    }
}
#endif
