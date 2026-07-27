import Foundation

public struct MatrixPoint: Equatable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct MatrixRipple: Equatable, Sendable {
    public let origin: MatrixPoint
    public let progress: Double

    public init(origin: MatrixPoint, progress: Double) {
        self.origin = origin
        self.progress = progress
    }
}

public struct LightingMatrixDimensions: Equatable, Sendable {
    public let rows: Int
    public let columns: Int

    public init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns
    }
}

public enum DeviceMatrixLayout {
    public static func dimensions(for device: RazerDevice) -> LightingMatrixDimensions? {
        guard device.kind == .keyboard || device.kind == .laptop else {
            return nil
        }
        if let dimensions = knownDimensions[device.productID] {
            return dimensions
        }

        let name = device.productName.lowercased()
        if name.contains("tartarus")
            || name.contains("orbweaver")
            || name.contains("nostromo") {
            return .init(rows: 4, columns: 6)
        }
        if name.contains("mini") {
            return .init(rows: 5, columns: 16)
        }
        if name.contains("tournament")
            || name.contains("tenkeyless")
            || name.contains(" tkl") {
            return .init(rows: 6, columns: 18)
        }
        if device.kind == .laptop {
            return .init(rows: 6, columns: 16)
        }
        return .init(rows: 6, columns: 22)
    }

    // Dimensions observed in the community device configurations imported for Raze.
    private static let knownDimensions: [UInt16: LightingMatrixDimensions] = [
        0x010D: .init(rows: 6, columns: 22),
        0x010E: .init(rows: 6, columns: 22),
        0x011A: .init(rows: 6, columns: 22),
        0x011B: .init(rows: 6, columns: 22),
        0x0203: .init(rows: 6, columns: 22),
        0x0204: .init(rows: 1, columns: 6),
        0x0205: .init(rows: 6, columns: 22),
        0x0207: .init(rows: 5, columns: 22),
        0x0209: .init(rows: 6, columns: 22),
        0x020F: .init(rows: 6, columns: 16),
        0x0210: .init(rows: 6, columns: 22),
        0x0211: .init(rows: 6, columns: 22),
        0x0214: .init(rows: 6, columns: 22),
        0x0216: .init(rows: 6, columns: 22),
        0x0217: .init(rows: 6, columns: 22),
        0x021A: .init(rows: 6, columns: 22),
        0x021E: .init(rows: 6, columns: 22),
        0x021F: .init(rows: 6, columns: 22),
        0x0220: .init(rows: 6, columns: 16),
        0x0221: .init(rows: 6, columns: 22),
        0x0224: .init(rows: 6, columns: 16),
        0x0225: .init(rows: 6, columns: 25),
        0x0226: .init(rows: 9, columns: 22),
        0x0227: .init(rows: 6, columns: 22),
        0x0228: .init(rows: 6, columns: 22),
        0x022A: .init(rows: 6, columns: 22),
        0x022B: .init(rows: 4, columns: 6),
        0x022C: .init(rows: 6, columns: 22),
        0x022D: .init(rows: 6, columns: 16),
        0x022F: .init(rows: 6, columns: 25),
        0x0232: .init(rows: 6, columns: 16),
        0x0233: .init(rows: 6, columns: 16),
        0x0237: .init(rows: 6, columns: 22),
        0x023A: .init(rows: 6, columns: 16),
        0x0240: .init(rows: 6, columns: 16),
        0x0241: .init(rows: 6, columns: 22),
        0x0243: .init(rows: 6, columns: 18),
        0x0245: .init(rows: 6, columns: 6),
        0x024D: .init(rows: 6, columns: 16),
        0x024E: .init(rows: 6, columns: 22),
        0x0257: .init(rows: 5, columns: 15),
        0x0258: .init(rows: 5, columns: 16),
        0x025A: .init(rows: 6, columns: 22),
        0x025D: .init(rows: 6, columns: 22),
        0x025E: .init(rows: 6, columns: 22),
        0x0266: .init(rows: 8, columns: 22),
        0x0269: .init(rows: 5, columns: 15),
        0x026B: .init(rows: 6, columns: 18),
        0x026C: .init(rows: 6, columns: 22),
        0x0271: .init(rows: 5, columns: 16),
        0x028D: .init(rows: 6, columns: 24),
        0x0295: .init(rows: 6, columns: 22),
        0x02A5: .init(rows: 6, columns: 15),
        0x0A24: .init(rows: 6, columns: 18)
    ]
}

public enum MatrixAnimations {
    public static func wheelFrame(rows: Int, columns: Int, phase: Double) -> [[RGBColor]] {
        guard rows > 0, columns > 0 else {
            return []
        }

        let centreRow = Double(rows - 1) / 2
        let centreColumn = Double(columns - 1) / 2
        return (0..<rows).map { row in
            (0..<columns).map { column in
                let angle = atan2(
                    Double(row) - centreRow,
                    Double(column) - centreColumn
                )
                let hue = positiveFraction(angle / (2 * .pi) + phase)
                return rgb(hue: hue, saturation: 1, brightness: 1)
            }
        }
    }

    public static func rippleFrame(
        rows: Int,
        columns: Int,
        ripples: [MatrixRipple],
        colour: RGBColor
    ) -> [[RGBColor]] {
        guard rows > 0, columns > 0 else {
            return []
        }
        let bandWidth = 1.6

        return (0..<rows).map { row in
            (0..<columns).map { column in
                let intensity = ripples.map { ripple in
                    let distance = hypot(
                        Double(column - ripple.origin.column),
                        Double(row - ripple.origin.row) * 2
                    )
                    let radius = ripple.progress * Double(max(rows, columns))
                    return max(0, 1 - abs(distance - radius) / bandWidth)
                }
                .max() ?? 0
                return scaled(colour, by: intensity)
            }
        }
    }

    private static func positiveFraction(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }

    private static func rgb(
        hue: Double,
        saturation: Double,
        brightness: Double
    ) -> RGBColor {
        let sector = hue * 6
        let index = Int(floor(sector))
        let fraction = sector - floor(sector)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - fraction * saturation)
        let t = brightness * (1 - (1 - fraction) * saturation)
        let values: (Double, Double, Double) = switch index % 6 {
        case 0: (brightness, t, p)
        case 1: (q, brightness, p)
        case 2: (p, brightness, t)
        case 3: (p, q, brightness)
        case 4: (t, p, brightness)
        default: (brightness, p, q)
        }
        return RGBColor(
            red: byte(values.0),
            green: byte(values.1),
            blue: byte(values.2)
        )
    }

    private static func scaled(_ colour: RGBColor, by value: Double) -> RGBColor {
        RGBColor(
            red: byte(Double(colour.red) / 255 * value),
            green: byte(Double(colour.green) / 255 * value),
            blue: byte(Double(colour.blue) / 255 * value)
        )
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()))
    }
}
