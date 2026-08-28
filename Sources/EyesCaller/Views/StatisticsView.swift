import SwiftUI

struct StatisticsView: View {
    @ObservedObject var statistics: EyeCareStatisticsStore
    @ObservedObject var appearance: AppearanceController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.vertical, showsIndicators: dynamicTypeSize.isAccessibilitySize) {
            VStack(spacing: 0) {
                header

                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    VStack(spacing: 16) {
                        metricCards

                        StatisticsHeatmapView(
                            statistics: statistics,
                            referenceDate: timeline.date
                        )
                    }
                }
                .padding(.top, 22)

                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                    Text("从 \(formattedFirstUsedDate) 开始记录，所有足迹只保存在这台 Mac 上")
                }
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(GardenTheme.mutedInk)
                .padding(.top, 22)
            }
            .padding(28)
        }
        .frame(width: 710, height: 590)
        .preferredColorScheme(appearance.mode.colorScheme)
        .background(GardenTheme.background(for: .focus))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: appearance.mode)
    }

    @ViewBuilder
    private var metricCards: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                metricCardViews
            }
        } else {
            HStack(spacing: 12) {
                metricCardViews
            }
        }
    }

    @ViewBuilder
    private var metricCardViews: some View {
        StatisticsMetricCard(
            symbol: "calendar",
            value: statistics.companionDays,
            unit: "天",
            label: "眺眺的陪伴",
            accent: GardenTheme.sunlight
        )

        StatisticsMetricCard(
            symbol: "sun.horizon.fill",
            value: statistics.todayCount,
            unit: "次",
            label: "今日远眺",
            accent: GardenTheme.sky
        )

        StatisticsMetricCard(
            symbol: "leaf.fill",
            value: statistics.totalCount,
            unit: "次",
            label: "累计远眺",
            accent: GardenTheme.mint
        )
    }

    private var header: some View {
        HStack(spacing: 13) {
            BrandMark()

            VStack(alignment: .leading, spacing: 4) {
                Text("远眺足迹")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(GardenTheme.ink)
                Text("每一次远眺，都在这里长成一小片绿意。")
                    .font(.system(.subheadline, design: .rounded))
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
            .accessibilityLabel("关闭远眺足迹")
        }
    }

    private var formattedFirstUsedDate: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: statistics.firstUsedAt
        )
        return "\(components.year ?? 0)年\(components.month ?? 0)月\(components.day ?? 0)日"
    }
}
