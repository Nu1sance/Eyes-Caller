import SwiftUI

struct CompactReminderView: View {
    @ObservedObject var appearance: AppearanceController
    let onStart: () -> Void
    let onSnooze: () -> Void
    let onOpenMainWindow: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            GardenTheme.background(for: .ready)

            Circle()
                .fill(GardenTheme.sunlight.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: 165, y: -108)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    BrandMark()
                    Text("眺眺提醒你")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GardenTheme.ink)

                    Spacer()

                    Button(action: onOpenMainWindow) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("打开主界面")
                    .accessibilityLabel("打开眺眺主界面")
                }

                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(GardenTheme.sunlight.opacity(0.28))
                            .frame(width: 56, height: 56)
                            .scaleEffect(isBreathing ? 1.08 : 0.94)
                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(GardenTheme.fern)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("该看看远处了")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(GardenTheme.ink)
                        Text("望向约 6 米外，给眼睛 20 秒的晴天。")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(GardenTheme.mutedInk)
                    }
                }
                .padding(.top, 20)

                HStack(spacing: 10) {
                    Button("开始远眺", action: onStart)
                        .buttonStyle(PrimaryGardenButtonStyle())
                        .keyboardShortcut(.defaultAction)

                    Button("5 分钟后", action: onSnooze)
                        .buttonStyle(SoftGardenButtonStyle())
                }
                .padding(.top, 22)
            }
            .padding(22)
        }
        .frame(width: 390, height: 238)
        .preferredColorScheme(appearance.mode.colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(GardenTheme.border, lineWidth: 1)
        )
        .background(PanelAppearanceAccessor(mode: appearance.mode))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: appearance.mode)
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
                isBreathing = false
            }
        } else {
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

private struct PanelAppearanceAccessor: NSViewRepresentable {
    let mode: AppearanceMode

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window, mode: mode)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window, mode: mode)
        }
    }

    @MainActor
    final class Coordinator {
        private weak var window: NSWindow?
        private var mode: AppearanceMode
        private nonisolated(unsafe) var displayOptionsObserver: NSObjectProtocol?

        init(mode: AppearanceMode) {
            self.mode = mode
            displayOptionsObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.applyAppearance()
                }
            }
        }

        deinit {
            if let displayOptionsObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(displayOptionsObserver)
            }
        }

        func attach(to window: NSWindow?, mode: AppearanceMode) {
            self.window = window
            self.mode = mode
            applyAppearance()
        }

        private func applyAppearance() {
            window?.appearance = GardenAppearance.resolved(for: mode)
        }
    }
}
