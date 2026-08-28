import SwiftUI

struct StatisticsHeatmapView: View {
    @ObservedObject var statistics: EyeCareStatisticsStore
    let referenceDate: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
    @ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption2) private var cellSpacing: CGFloat = 5
    @ScaledMetric(relativeTo: .caption2) private var labelWidth: CGFloat = 18
    @ScaledMetric(relativeTo: .caption2) private var monthLabelHeight: CGFloat = 13

    var body: some View {
        let weeks = makeWeeks(endingAt: referenceDate)

        VStack(alignment: .leading, spacing: 16) {
            heatmapHeader

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal, showsIndicators: true) {
                    heatmapGrid(weeks: weeks)
                        .padding(.bottom, 6)
                }
            } else {
                heatmapGrid(weeks: weeks)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .gardenCard()
    }

    @ViewBuilder
    private var heatmapHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 9) {
                heatmapTitle
                ActivityLegend()
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                heatmapTitle
                Spacer()
                ActivityLegend()
            }
        }
    }

    private var heatmapTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("最近 12 周")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(GardenTheme.ink)
            Text("颜色越深，这一天看向远处的次数越多")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(GardenTheme.mutedInk)
        }
    }

    private func heatmapGrid(weeks: [[HeatmapEntry]]) -> some View {
        HStack(alignment: .top, spacing: 9) {
            weekdayLabels

            VStack(alignment: .leading, spacing: cellSpacing) {
                monthLabels(for: weeks)

                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: cellSpacing) {
                            ForEach(week) { entry in
                                HeatmapCell(
                                    entry: entry,
                                    count: statistics.count(on: entry.date),
                                    size: cellSize
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var weekdayLabels: some View {
        VStack(spacing: cellSpacing) {
            Color.clear
                .frame(width: labelWidth, height: monthLabelHeight)

            ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabel(at: index))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(GardenTheme.mutedInk)
                    .frame(width: labelWidth, height: cellSize)
            }
        }
    }

    private func monthLabels(for weeks: [[HeatmapEntry]]) -> some View {
        HStack(spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                Text(monthLabel(for: week, at: index, allWeeks: weeks))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(GardenTheme.mutedInk)
                    .frame(width: cellSize, height: monthLabelHeight, alignment: .leading)
            }
        }
    }

    private func makeWeeks(endingAt date: Date) -> [[HeatmapEntry]] {
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        let daysAfterMonday = (weekday + 5) % 7
        let currentWeekStart = calendar.date(
            byAdding: .day,
            value: -daysAfterMonday,
            to: today
        ) ?? today
        let gridStart = calendar.date(
            byAdding: .weekOfYear,
            value: -11,
            to: currentWeekStart
        ) ?? currentWeekStart

        return (0..<12).map { weekOffset in
            (0..<7).compactMap { dayOffset in
                guard let weekStart = calendar.date(
                    byAdding: .weekOfYear,
                    value: weekOffset,
                    to: gridStart
                ), let day = calendar.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: weekStart
                ) else { return nil }

                return HeatmapEntry(
                    date: day,
                    isToday: calendar.isDate(day, inSameDayAs: today),
                    isFuture: day > today
                )
            }
        }
    }

    private func weekdayLabel(at index: Int) -> String {
        switch index {
        case 0: "一"
        case 2: "三"
        case 4: "五"
        case 6: "日"
        default: ""
        }
    }

    private func monthLabel(
        for week: [HeatmapEntry],
        at index: Int,
        allWeeks: [[HeatmapEntry]]
    ) -> String {
        guard let date = week.first?.date else { return "" }
        let month = calendar.component(.month, from: date)
        if index == 0 {
            return "\(month)月"
        }

        guard let previousDate = allWeeks[index - 1].first?.date else { return "" }
        let previousMonth = calendar.component(.month, from: previousDate)
        return month == previousMonth ? "" : "\(month)月"
    }
}

private struct HeatmapEntry: Identifiable {
    let date: Date
    let isToday: Bool
    let isFuture: Bool

    var id: Date { date }
}

private struct HeatmapCell: View {
    let entry: HeatmapEntry
    let count: Int
    let size: CGFloat

    var body: some View {
        if entry.isFuture {
            Color.clear
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            entry.isToday ? GardenTheme.ink.opacity(0.78) : GardenTheme.subtleBorder,
                            lineWidth: entry.isToday ? 1.8 : 1
                        )
                )
                .frame(width: size, height: size)
                .shadow(
                    color: entry.isToday ? GardenTheme.sunlight.opacity(0.45) : .clear,
                    radius: 4
                )
                .help(tooltip)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tooltip)
        }
    }

    private var fillColor: Color {
        switch count {
        case 0: GardenTheme.activityEmpty
        case 1: GardenTheme.activityLow
        case 2: GardenTheme.activityMedium
        case 3: GardenTheme.activityHigh
        default: GardenTheme.activityPeak
        }
    }

    private var tooltip: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day], from: entry.date)
        let dateText = "\(components.year ?? 0)年\(components.month ?? 0)月\(components.day ?? 0)日"
        return "\(dateText)，完成 \(count) 次远眺"
    }
}

private struct ActivityLegend: View {
    @ScaledMetric(relativeTo: .caption2) private var legendCellSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 5) {
            Text("少")
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: level))
                    .frame(width: legendCellSize, height: legendCellSize)
            }
            Text("多")
        }
        .font(.system(.caption2, design: .rounded, weight: .semibold))
        .foregroundStyle(GardenTheme.mutedInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("活跃程度图例，从少到多")
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: GardenTheme.activityEmpty
        case 1: GardenTheme.activityLow
        case 2: GardenTheme.activityMedium
        case 3: GardenTheme.activityHigh
        default: GardenTheme.activityPeak
        }
    }
}
