import SwiftUI

enum ReminderStyle: String, CaseIterable, Identifiable, Sendable {
    case notificationOnly
    case notificationAndPopup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notificationOnly: "仅系统通知"
        case .notificationAndPopup: "通知 + 小弹窗"
        }
    }

    var detail: String {
        switch self {
        case .notificationOnly: "安静地留在通知中心，不打断当前工作"
        case .notificationAndPopup: "通知同时出现轻量窗口，更容易被注意到"
        }
    }

    var symbol: String {
        switch self {
        case .notificationOnly: "bell"
        case .notificationAndPopup: "macwindow.and.cursorarrow"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appearance: AppearanceController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reminderStyle") private var reminderStyle = ReminderStyle.notificationAndPopup.rawValue
    @AppStorage("playGentleSound") private var playGentleSound = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(GardenTheme.ink)
                    Text("安排提醒，也安排舒服的昼夜节奏")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(GardenTheme.mutedInk)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("关闭设置")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("提醒出现时")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GardenTheme.mutedInk)
                    .textCase(.uppercase)
                    .tracking(0.8)

                ForEach(ReminderStyle.allCases) { style in
                    ReminderChoiceRow(
                        style: style,
                        isSelected: reminderStyle == style.rawValue
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reminderStyle = style.rawValue
                        }
                    }
                }
            }
            .padding(20)
            .gardenCard()
            .padding(.top, 24)

            appearanceSection
                .padding(20)
                .gardenCard()
                .padding(.top, 14)

            HStack(spacing: 15) {
                Image(systemName: "music.note")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GardenTheme.fern)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(GardenTheme.mint))

                VStack(alignment: .leading, spacing: 3) {
                    Text("完成提示音")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GardenTheme.ink)
                    Text("20 秒结束时播放一声轻柔提示")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GardenTheme.mutedInk)
                }

                Spacer()

                Toggle("完成提示音", isOn: $playGentleSound)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(GardenTheme.fern)
                    .accessibilityLabel("完成提示音")
                    .accessibilityHint("远眺 20 秒完成时播放轻柔提示")
            }
            .padding(18)
            .gardenCard()
            .padding(.top, 14)

            HStack(spacing: 0) {
                MetricItem(value: "20 分钟", label: "专注")
                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 24)
                MetricItem(value: "20 秒", label: "远眺")
                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 24)
                MetricItem(value: "约 6 米", label: "距离")
            }
            .padding(.top, 24)

            Spacer()

            Text("系统通知不可用时，会自动使用小弹窗确保提醒不被错过。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
        }
        .padding(28)
        .frame(width: 560, height: 710)
        .preferredColorScheme(appearance.mode.colorScheme)
        .background(GardenTheme.background(for: .focus))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: appearance.mode)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: appearance.mode == .day ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GardenTheme.fern)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(GardenTheme.mint))

                VStack(alignment: .leading, spacing: 3) {
                    Text("定时切换昼夜")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GardenTheme.ink)
                    Text("到时间后自动使用更舒适的屏幕配色")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GardenTheme.mutedInk)
                }

                Spacer()

                Toggle(
                    "定时切换昼夜",
                    isOn: Binding(
                        get: { appearance.automaticEnabled },
                        set: { appearance.setAutomaticEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(GardenTheme.fern)
            }

            if appearance.automaticEnabled {
                Divider()
                    .overlay(GardenTheme.subtleBorder)

                HStack(spacing: 18) {
                    DatePicker(
                        "白天开始",
                        selection: Binding(
                            get: { appearance.dateForTimePicker(minutes: appearance.dayStartMinutes) },
                            set: { appearance.setDayStart(from: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "夜晚开始",
                        selection: Binding(
                            get: { appearance.dateForTimePicker(minutes: appearance.nightStartMinutes) },
                            set: { appearance.setNightStart(from: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GardenTheme.ink)
                .datePickerStyle(.compact)

                HStack(spacing: 7) {
                    Image(systemName: appearance.isTemporarilyOverridden ? "clock.arrow.circlepath" : "sparkles")
                    Text(scheduleNote)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
            } else {
                Text("自动切换已关闭，可随时使用主界面的太阳或月亮按钮。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GardenTheme.mutedInk)
            }
        }
    }

    private var scheduleNote: String {
        if appearance.isTemporarilyOverridden, let expiresAt = appearance.overrideExpiresAt {
            return "当前为临时切换，将在 \(timeString(expiresAt)) 恢复自动计划"
        }
        return "每天 \(timeString(appearance.dayStartMinutes)) 进入白天，\(timeString(appearance.nightStartMinutes)) 进入夜晚"
    }

    private func timeString(_ minutes: Int) -> String {
        timeString(appearance.dateForTimePicker(minutes: minutes))
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct ReminderChoiceRow: View {
    let style: ReminderStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: style.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? GardenTheme.buttonText : GardenTheme.fern)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(isSelected ? GardenTheme.fern : GardenTheme.mint.opacity(0.8))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GardenTheme.ink)
                    Text(style.detail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GardenTheme.mutedInk)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? GardenTheme.fern : GardenTheme.leaf.opacity(0.45))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? GardenTheme.mint.opacity(0.72) : GardenTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? GardenTheme.leaf.opacity(0.44) : GardenTheme.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MetricItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(GardenTheme.ink)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
    }
}
