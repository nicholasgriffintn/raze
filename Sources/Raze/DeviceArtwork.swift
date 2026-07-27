#if os(macOS)
import RazerCore
import SwiftUI

struct DeviceArtwork: View {
    let kind: DeviceKind
    var selectedTarget: LightingTarget?
    var availableTargets: [LightingTarget] = []
    var onSelectTarget: ((LightingTarget) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.78),
                                Color.green.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                DeviceSchematic(kind: kind)
                    .padding(18)

                ForEach(availableTargets, id: \.self) { target in
                    Button {
                        onSelectTarget?(target)
                    } label: {
                        ZoneHotspot(isSelected: selectedTarget == target)
                    }
                    .buttonStyle(.plain)
                    .position(DeviceZoneLayout.position(for: target, kind: kind, in: proxy.size))
                    .accessibilityLabel(target.displayName)
                    .accessibilityValue(
                        selectedTarget == target ? "Selected" : "Not selected"
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.22))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .aspectRatio(1.65, contentMode: .fit)
    }
}

struct DeviceZoneSelector: View {
    let device: RazerDevice
    @Binding var selection: LightingTarget

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            DeviceArtwork(
                kind: device.kind,
                selectedTarget: selection,
                availableTargets: device.targets,
                onSelectTarget: { selection = $0 }
            )
            .frame(minWidth: 230, idealWidth: 290, maxWidth: 330)

            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a zone")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(device.targets, id: \.self) { target in
                    Button {
                        selection = target
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: target.systemImage)
                                .frame(width: 18)
                            Text(target.displayName)
                            Spacer(minLength: 8)
                            Image(
                                systemName: selection == target
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                selection == target ? Color.green : Color.secondary
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        selection == target
                            ? Color.green.opacity(0.13)
                            : Color.primary.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
            }
            .frame(minWidth: 170, maxWidth: 220)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lighting zones")
    }
}

private struct ZoneHotspot: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.green : Color.black.opacity(0.72))
            Circle()
                .strokeBorder(
                    isSelected ? Color.white.opacity(0.9) : Color.green.opacity(0.72),
                    lineWidth: 1.5
                )
            if isSelected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
        .shadow(color: Color.green.opacity(isSelected ? 0.75 : 0.3), radius: 7)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

private struct DeviceSchematic: View {
    let kind: DeviceKind

    var body: some View {
        Canvas { context, size in
            let line = GraphicsContext.Shading.color(Color.green.opacity(0.88))
            let muted = GraphicsContext.Shading.color(Color.green.opacity(0.22))
            let rect = CGRect(origin: .zero, size: size)

            switch kind {
            case .mouse:
                drawMouse(in: &context, rect: rect, line: line, muted: muted)
            case .keyboard:
                drawKeyboard(in: &context, rect: rect, line: line, muted: muted)
            case .laptop:
                drawLaptop(in: &context, rect: rect, line: line, muted: muted)
            case .headset:
                drawHeadset(in: &context, rect: rect, line: line, muted: muted)
            case .accessory, .unknown:
                drawAccessory(in: &context, rect: rect, line: line, muted: muted)
            }
        }
        .shadow(color: Color.green.opacity(0.25), radius: 9)
    }

    private func drawMouse(
        in context: inout GraphicsContext,
        rect: CGRect,
        line: GraphicsContext.Shading,
        muted: GraphicsContext.Shading
    ) {
        let shell = CGRect(
            x: rect.width * 0.33,
            y: rect.height * 0.05,
            width: rect.width * 0.34,
            height: rect.height * 0.90
        )
        let body = Path(ellipseIn: shell)
        context.fill(body, with: muted)
        context.stroke(body, with: line, lineWidth: 2)

        var centreLine = Path()
        centreLine.move(to: CGPoint(x: rect.midX, y: shell.minY))
        centreLine.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.35))
        context.stroke(centreLine, with: line, lineWidth: 1)

        let wheel = CGRect(
            x: rect.midX - rect.width * 0.025,
            y: rect.height * 0.17,
            width: rect.width * 0.05,
            height: rect.height * 0.14
        )
        context.fill(Path(roundedRect: wheel, cornerRadius: wheel.width / 2), with: line)
    }

    private func drawKeyboard(
        in context: inout GraphicsContext,
        rect: CGRect,
        line: GraphicsContext.Shading,
        muted: GraphicsContext.Shading
    ) {
        let board = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.17)
        let outline = Path(roundedRect: board, cornerRadius: 12)
        context.fill(outline, with: muted)
        context.stroke(outline, with: line, lineWidth: 2)

        let columns = 12
        let rows = 4
        let gap = rect.width * 0.012
        let keyWidth = (board.width - gap * Double(columns + 1)) / Double(columns)
        let keyHeight = (board.height - gap * Double(rows + 1)) / Double(rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let key = CGRect(
                    x: board.minX + gap + Double(column) * (keyWidth + gap),
                    y: board.minY + gap + Double(row) * (keyHeight + gap),
                    width: keyWidth,
                    height: keyHeight
                )
                context.stroke(
                    Path(roundedRect: key, cornerRadius: 2),
                    with: GraphicsContext.Shading.color(Color.green.opacity(0.28)),
                    lineWidth: 0.7
                )
            }
        }
    }

    private func drawLaptop(
        in context: inout GraphicsContext,
        rect: CGRect,
        line: GraphicsContext.Shading,
        muted: GraphicsContext.Shading
    ) {
        let screen = CGRect(
            x: rect.width * 0.18,
            y: rect.height * 0.05,
            width: rect.width * 0.64,
            height: rect.height * 0.62
        )
        context.fill(Path(roundedRect: screen, cornerRadius: 10), with: muted)
        context.stroke(Path(roundedRect: screen, cornerRadius: 10), with: line, lineWidth: 2)

        var base = Path()
        base.move(to: CGPoint(x: rect.width * 0.11, y: rect.height * 0.72))
        base.addLine(to: CGPoint(x: rect.width * 0.89, y: rect.height * 0.72))
        base.addLine(to: CGPoint(x: rect.width * 0.96, y: rect.height * 0.90))
        base.addLine(to: CGPoint(x: rect.width * 0.04, y: rect.height * 0.90))
        base.closeSubpath()
        context.fill(base, with: muted)
        context.stroke(base, with: line, lineWidth: 2)
    }

    private func drawHeadset(
        in context: inout GraphicsContext,
        rect: CGRect,
        line: GraphicsContext.Shading,
        muted: GraphicsContext.Shading
    ) {
        var band = Path()
        band.addArc(
            center: CGPoint(x: rect.midX, y: rect.height * 0.55),
            radius: min(rect.width, rect.height) * 0.38,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        context.stroke(band, with: line, lineWidth: 8)

        for x in [rect.width * 0.22, rect.width * 0.68] {
            let cup = CGRect(
                x: x,
                y: rect.height * 0.52,
                width: rect.width * 0.10,
                height: rect.height * 0.30
            )
            context.fill(Path(roundedRect: cup, cornerRadius: 8), with: muted)
            context.stroke(Path(roundedRect: cup, cornerRadius: 8), with: line, lineWidth: 2)
        }
    }

    private func drawAccessory(
        in context: inout GraphicsContext,
        rect: CGRect,
        line: GraphicsContext.Shading,
        muted: GraphicsContext.Shading
    ) {
        let size = min(rect.width, rect.height) * 0.64
        let ring = CGRect(
            x: rect.midX - size / 2,
            y: rect.midY - size / 2,
            width: size,
            height: size
        )
        context.fill(Path(ellipseIn: ring), with: muted)
        context.stroke(Path(ellipseIn: ring), with: line, lineWidth: 2)
        context.stroke(
            Path(ellipseIn: ring.insetBy(dx: size * 0.19, dy: size * 0.19)),
            with: line,
            lineWidth: 1
        )
    }
}

enum DeviceZoneLayout {
    static func position(
        for target: LightingTarget,
        kind: DeviceKind,
        in size: CGSize
    ) -> CGPoint {
        let relativePosition: CGPoint
        switch target {
        case .scrollWheel:
            relativePosition = CGPoint(x: 0.50, y: kind == .mouse ? 0.31 : 0.24)
        case .logo:
            relativePosition = CGPoint(x: 0.50, y: kind == .mouse ? 0.64 : 0.48)
        case .battery:
            relativePosition = CGPoint(x: 0.72, y: 0.73)
        case .backlight:
            relativePosition = CGPoint(x: 0.50, y: 0.50)
        case .all:
            relativePosition = CGPoint(x: 0.77, y: 0.22)
        }
        return CGPoint(
            x: size.width * relativePosition.x,
            y: size.height * relativePosition.y
        )
    }
}
#endif
