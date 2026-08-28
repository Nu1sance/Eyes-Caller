import AppKit
import SwiftUI

// A calm garden by day and a deep teal moonlit garden by night. Every shared
// surface uses semantic colors so sheets, controls and reminders change as one.
enum GardenTheme {
    static let mist = Color.adaptive(light: 0xF5FAF4, dark: 0x0D1C1A)
    static let mint = Color.adaptive(light: 0xDCEFE0, dark: 0x203A34)
    static let leaf = Color.adaptive(light: 0x7EAE8A, dark: 0x79AD8F)
    static let fern = Color.adaptive(light: 0x3F6955, dark: 0x8AB79A)
    static let ink = Color.adaptive(light: 0x29483B, dark: 0xE4F1EA)
    static let mutedInk = Color.adaptive(light: 0x526A5F, dark: 0xA9BFB5)
    static let sky = Color.adaptive(light: 0xCDE9EA, dark: 0x25434A)
    static let skyDeep = Color.adaptive(light: 0x8EC8CE, dark: 0x78B1B8)
    static let sunlight = Color.adaptive(light: 0xF4D98E, dark: 0xE7C979)

    static let surface = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0x1B302D,
        lightAlpha: 0.56,
        darkAlpha: 0.88
    )
    static let surfaceStrong = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0x233C37,
        lightAlpha: 0.78,
        darkAlpha: 0.96
    )
    static let border = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0xA2C5B8,
        lightAlpha: 0.72,
        darkAlpha: 0.2
    )
    static let subtleBorder = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0x83A99B,
        lightAlpha: 0.52,
        darkAlpha: 0.14
    )
    static let buttonText = Color.adaptive(light: 0xFFFFFF, dark: 0x10251E)
    static let progressTrack = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0x87AA9E,
        lightAlpha: 0.48,
        darkAlpha: 0.2
    )
    static let ambientGlow = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0x6FA695,
        lightAlpha: 0.2,
        darkAlpha: 0.08
    )
    static let shadow = Color.adaptive(
        light: 0x3F6955,
        dark: 0x000000,
        lightAlpha: 0.12,
        darkAlpha: 0.34
    )

    static let activityEmpty = Color.adaptive(
        light: 0xFFFFFF,
        dark: 0x263A36,
        lightAlpha: 0.58,
        darkAlpha: 0.9
    )
    static let activityLow = Color.adaptive(light: 0xCFE7D3, dark: 0x31584A)
    static let activityMedium = Color.adaptive(light: 0xA2CDAA, dark: 0x477B61)
    static let activityHigh = Color.adaptive(light: 0x72A982, dark: 0x68A47E)
    static let activityPeak = Color.adaptive(light: 0x3F6955, dark: 0x94C6A2)

    static func background(for phase: SessionPhase) -> LinearGradient {
        let colors: [Color]
        switch phase {
        case .completed:
            colors = [
                Color.adaptive(light: 0xDFF3EE, dark: 0x163036),
                Color.adaptive(light: 0xC8E9EC, dark: 0x1B3934)
            ]
        case .resting:
            colors = [
                Color.adaptive(light: 0xEEF8EF, dark: 0x102723),
                Color.adaptive(light: 0xD8EEE3, dark: 0x18332C)
            ]
        case .focus, .ready:
            colors = [
                mist,
                Color.adaptive(light: 0xE7F4E8, dark: 0x142A26)
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }

    static func adaptive(
        light: UInt,
        dark: UInt,
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [
                    .accessibilityHighContrastDarkAqua,
                    .darkAqua,
                    .accessibilityHighContrastAqua,
                    .aqua
                ])
                let usesDarkColors = match == .darkAqua
                    || match == .accessibilityHighContrastDarkAqua
                return NSColor(
                    hex: usesDarkColors ? dark : light,
                    alpha: usesDarkColors ? darkAlpha : lightAlpha
                )
            }
        )
    }
}

private extension NSColor {
    convenience init(hex: UInt, alpha: Double = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

@MainActor
enum GardenAppearance {
    static func resolved(for mode: AppearanceMode) -> NSAppearance? {
        let increasedContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let name: NSAppearance.Name
        if mode == .night {
            name = increasedContrast ? .accessibilityHighContrastDarkAqua : .darkAqua
        } else {
            name = increasedContrast ? .accessibilityHighContrastAqua : .aqua
        }
        return NSAppearance(named: name)
    }
}

struct GardenCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(GardenTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(GardenTheme.border, lineWidth: 1)
                    )
                    .shadow(color: GardenTheme.shadow, radius: 24, y: 12)
            )
    }
}

extension View {
    func gardenCard() -> some View {
        modifier(GardenCardModifier())
    }
}
