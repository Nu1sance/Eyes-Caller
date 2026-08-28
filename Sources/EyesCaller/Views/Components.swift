import SwiftUI

struct BrandMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(GardenTheme.mint)

            Capsule(style: .continuous)
                .fill(GardenTheme.fern)
                .frame(width: 18, height: 11)
                .rotationEffect(.degrees(-28))
                .offset(x: -3, y: 1)

            Circle()
                .fill(GardenTheme.sunlight)
                .frame(width: 5, height: 5)
                .offset(x: 7, y: -7)
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let phase: SessionPhase

    private var label: String {
        switch phase {
        case .focus: "专注中"
        case .ready: "该休息啦"
        case .resting: "正在远眺"
        case .completed: "本轮完成"
        }
    }

    private var dotColor: Color {
        phase == .completed ? GardenTheme.skyDeep : GardenTheme.leaf
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(GardenTheme.surface))
        .overlay(Capsule().stroke(GardenTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryGardenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(GardenTheme.buttonText)
            .padding(.horizontal, 22)
            .frame(height: 48)
            .background(
                Capsule(style: .continuous)
                    .fill(GardenTheme.fern)
                    .shadow(
                        color: GardenTheme.fern.opacity(configuration.isPressed ? 0.08 : 0.2),
                        radius: configuration.isPressed ? 3 : 10,
                        y: configuration.isPressed ? 2 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SoftGardenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(GardenTheme.fern)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? GardenTheme.surfaceStrong : GardenTheme.surface)
                    .overlay(Capsule().stroke(GardenTheme.border, lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(GardenTheme.ink)
            .frame(width: 36, height: 36)
            .background(Circle().fill(configuration.isPressed ? GardenTheme.surfaceStrong : GardenTheme.surface))
            .overlay(Circle().stroke(GardenTheme.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CircularProgressRing: View {
    let progress: Double
    let seconds: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(GardenTheme.progressTrack, lineWidth: 9)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    GardenTheme.fern,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: -2) {
                Text("\(seconds)")
                    .font(.system(size: 58, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GardenTheme.ink)
                    .contentTransition(.numericText())
                Text("秒")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(GardenTheme.mutedInk)
            }
        }
        .frame(width: 154, height: 154)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("远眺倒计时")
        .accessibilityValue("剩余 \(seconds) 秒")
    }
}
