import SwiftUI

struct StatisticsMetricCard: View {
    let symbol: String
    let value: Int
    let unit: String
    let label: String
    let accent: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GardenTheme.fern)
                .frame(width: 40, height: 40)
                .background(Circle().fill(accent.opacity(0.45)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(value)")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(GardenTheme.ink)

                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(GardenTheme.mutedInk)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(GardenTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(GardenTheme.border, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label)，\(value) \(unit)")
    }
}
