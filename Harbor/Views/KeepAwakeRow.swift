import AppKit
import SwiftUI

/// The switch that keeps the Mac awake, so whatever is running can carry on through the night.
struct KeepAwakeRow: View {
    @Environment(NightWatch.self) private var watch
    @State private var phrase: String?

    var body: some View {
        HStack(spacing: 10) {
            WatchIcon(isOn: watch.isOn)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Keep Mac awake")
                    .font(.system(size: 13, weight: .semibold))

                Group {
                    if let phrase {
                        Text(phrase).foregroundStyle(.tint)
                    } else {
                        Text(status).foregroundStyle(.secondary).id(status)
                    }
                }
                .font(.system(size: 11))
                .lineLimit(1)
                .transition(.blurReplace)
            }

            Spacer(minLength: 6)

            Toggle("Keep Mac awake", isOn: Binding(get: { watch.isOn }, set: toggle))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect(cornerRadius: 16))
        .glassEffect(
            watch.isOn ? .regular.tint(.orange.opacity(0.12)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .onTapGesture { toggle(!watch.isOn) }
        .animation(.smooth(duration: 0.35), value: watch.isOn)
        .help("Stops the Mac and its display from sleeping while this is on")
    }

    private var status: String {
        guard watch.isOn else { return "Sleeps as usual" }
        return SleepBlocker.hasLid ? "Stays up, lid open or closed" : "Stays up until you say so"
    }

    private func toggle(_ on: Bool) {
        guard on != watch.isOn else { return }
        let changed = withAnimation(.bouncy(duration: 0.4)) { watch.set(on) }
        if changed {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        let line = changed ? WatchPhrases.next(on: on) : "Couldn't take the watch"
        withAnimation(.snappy) { phrase = line }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if phrase == line {
                withAnimation(.smooth) { phrase = nil }
            }
        }
    }
}

/// A little send-off each time the watch changes hands.
enum WatchPhrases {
    private static let takingWatch = ["Night watch posted", "Lantern lit", "Coffee's on, captain", "All hands awake", "Eyes on the horizon"]
    private static let standingDown = ["Watch relieved", "Lights out", "Sweet dreams, sailor", "Hammock time"]

    static func next(on: Bool) -> String {
        (on ? takingWatch : standingDown).randomElement()!
    }
}

/// A sleepy moon while off; a lookout's binoculars, glancing about now and then, while on.
private struct WatchIcon: View {
    let isOn: Bool

    var body: some View {
        Image(systemName: isOn ? "binoculars.fill" : "moon.zzz.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 5)), isActive: isOn)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isOn ? AnyShapeStyle(.orange.opacity(0.18)) : AnyShapeStyle(.quaternary), in: .circle)
            .background {
                if isOn { LanternGlow() }
            }
    }
}

private struct LanternGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    var body: some View {
        Circle()
            .fill(.orange.opacity(0.35))
            .scaleEffect(glowing ? 1.45 : 1)
            .opacity(glowing ? 0 : 0.8)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { glowing = true }
            }
    }
}
