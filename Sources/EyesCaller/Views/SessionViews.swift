import SwiftUI

struct SessionContentView: View {
    @ObservedObject var model: RestSessionModel

    var body: some View {
        Group {
            switch model.phase {
            case .focus:
                FocusSessionView(model: model)
            case .ready:
                RestReadyView(model: model)
            case .resting:
                RestingView(model: model)
            case .completed:
                RestCompletedView(model: model)
            }
        }
        .id(model.phase)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            )
        )
    }
}

private struct FocusSessionView: View {
    @ObservedObject var model: RestSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("下一次，看看远处")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.fern)

            Text(model.formattedFocusTime)
                .font(.system(size: 64, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(GardenTheme.ink)
                .padding(.top, 8)
                .contentTransition(.numericText())
                .accessibilityLabel("距离下次远眺还有 \(model.formattedFocusTime)")

            Text("先安心做手边的事。到时间，眺眺会轻轻提醒你。")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            HStack(spacing: 12) {
                Button {
                    model.startRest()
                } label: {
                    Label("现在远眺", systemImage: "eye")
                }
                .buttonStyle(PrimaryGardenButtonStyle())

                Button {
                    model.showReminderPreview()
                } label: {
                    Text("预览提醒")
                }
                .buttonStyle(SoftGardenButtonStyle())
                .help("预览 20 分钟后出现的提醒界面")
            }
            .padding(.top, 30)

            Spacer()

            PrincipleNote()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct RestReadyView: View {
    @ObservedObject var model: RestSessionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(GardenTheme.sunlight.opacity(0.24))
                    .frame(width: 60, height: 60)
                    .scaleEffect(breathe ? 1.13 : 0.94)
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(GardenTheme.fern)
            }
            .padding(.bottom, 22)

            Text("该看看远处了")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.ink)

            Text("找一个约 6 米外的目标，让眼睛慢慢放松。只需要 20 秒。")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Button {
                model.startRest()
            } label: {
                HStack(spacing: 9) {
                    Text("开始远眺")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryGardenButtonStyle())
            .keyboardShortcut(.defaultAction)
            .padding(.top, 30)

            if model.isReminderPreview {
                Button("返回工作计时") {
                    model.closeReminderPreview()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
                .padding(.top, 18)
            } else {
                Button("5 分钟后再提醒") {
                    model.snooze()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
                .padding(.top, 18)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            updateBreathing(for: reduceMotion)
        }
        .onChange(of: reduceMotion) { shouldReduceMotion in
            updateBreathing(for: shouldReduceMotion)
        }
    }

    private func updateBreathing(for shouldReduceMotion: Bool) {
        if shouldReduceMotion {
            withAnimation(.linear(duration: 0)) {
                breathe = false
            }
        } else {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

private struct RestingView: View {
    @ObservedObject var model: RestSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CircularProgressRing(
                progress: model.restProgress,
                seconds: model.restSecondsRemaining
            )

            Text("把目光放远一点")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.ink)
                .padding(.top, 24)

            Text("不用盯着倒计时。望向窗外、远处的树，或房间最远的角落。")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                Text("完成后会用颜色告诉你")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(GardenTheme.mutedInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct RestCompletedView: View {
    @ObservedObject var model: RestSessionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(GardenTheme.surfaceStrong)
                    .frame(width: 76, height: 76)
                    .scaleEffect(appeared ? 1 : 0.72)

                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(GardenTheme.fern)
                    .scaleEffect(appeared ? 1 : 0.5)
            }

            Text("远眺完成")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.ink)
                .padding(.top, 24)

            Text("这 20 秒，是送给眼睛的一小片晴天。下一轮已经轻轻开始。")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Button("回到工作") {
                model.returnToFocus()
            }
            .buttonStyle(SoftGardenButtonStyle())
            .padding(.top, 28)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.62)) {
                appeared = true
            }
        }
    }
}

private struct PrincipleNote: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 13))
                .foregroundStyle(GardenTheme.leaf)
                .frame(width: 32, height: 32)
                .background(Circle().fill(GardenTheme.mint.opacity(0.72)))

            VStack(alignment: .leading, spacing: 3) {
                Text("20 · 20 · 20")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GardenTheme.ink)
                Text("每 20 分钟，远眺约 6 米外 20 秒")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GardenTheme.mutedInk)
            }
        }
        .padding(.vertical, 10)
    }
}
