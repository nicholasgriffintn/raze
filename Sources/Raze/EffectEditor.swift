#if os(macOS)
import RazerCore
import SwiftUI

struct EffectEditor: View {
    @Binding var effect: LightingEffect
    let supportedKinds: Set<LightingEffectKind>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Effect", selection: effectKind) {
                ForEach(LightingEffectKind.allCases.filter(supportedKinds.contains), id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }

            if effect.kind.usesColour {
                ColorPicker(
                    "Colour",
                    selection: primaryColour,
                    supportsOpacity: false
                )
            }

            switch effect {
            case .reactive:
                Picker("Speed", selection: reactiveSpeed) {
                    Text("Short").tag(ReactiveSpeed.short)
                    Text("Medium").tag(ReactiveSpeed.medium)
                    Text("Long").tag(ReactiveSpeed.long)
                }
            case .wave:
                Picker("Direction", selection: waveDirection) {
                    Text("Left").tag(WaveDirection.left)
                    Text("Right").tag(WaveDirection.right)
                }
            case .starlight:
                Picker("Speed", selection: starlightSpeed) {
                    Text("Fast").tag(StarlightSpeed.fast)
                    Text("Medium").tag(StarlightSpeed.medium)
                    Text("Slow").tag(StarlightSpeed.slow)
                }
            default:
                EmptyView()
            }
        }
    }

    private var effectKind: Binding<LightingEffectKind> {
        Binding(
            get: { effect.kind },
            set: { kind in
                effect = effect.changingKind(to: kind)
            }
        )
    }

    private var primaryColour: Binding<Color> {
        Binding(
            get: { Color(razerColor: effect.primaryColor) },
            set: { newValue in
                let colour = newValue.razerRGB
                switch effect {
                case .staticColor:
                    effect = .staticColor(colour)
                case .breathing(_, let second):
                    effect = .breathing(colour, second)
                case .reactive(_, let speed):
                    effect = .reactive(colour, speed)
                case .starlight(_, let second, let speed):
                    effect = .starlight(colour, second, speed)
                case .ripple:
                    effect = .ripple(colour)
                default:
                    break
                }
            }
        )
    }

    private var reactiveSpeed: Binding<ReactiveSpeed> {
        Binding(
            get: {
                if case .reactive(_, let speed) = effect {
                    return speed
                }
                return .medium
            },
            set: {
                effect = .reactive(effect.primaryColor, $0)
            }
        )
    }

    private var waveDirection: Binding<WaveDirection> {
        Binding(
            get: {
                if case .wave(let direction) = effect {
                    return direction
                }
                return .left
            },
            set: { effect = .wave($0) }
        )
    }

    private var starlightSpeed: Binding<StarlightSpeed> {
        Binding(
            get: {
                if case .starlight(_, _, let speed) = effect {
                    return speed
                }
                return .medium
            },
            set: { effect = .starlight(effect.primaryColor, nil, $0) }
        )
    }
}
#endif
