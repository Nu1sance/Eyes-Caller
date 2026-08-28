import AppKit
import Combine
import SwiftUI

struct EyesCallerRootView: View {
    @ObservedObject var model: RestSessionModel
    @ObservedObject var statistics: EyeCareStatisticsStore
    @ObservedObject var appearance: AppearanceController
    @State private var activeSheet: RootSheet?
    @AppStorage("playGentleSound") private var playGentleSound = true
    @AppStorage("reminderStyle") private var reminderStyle = ReminderStyle.notificationAndPopup.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GardenTheme.background(for: model.phase)
                .ignoresSafeArea()

            ambientShapes

            VStack(spacing: 0) {
                topBar

                HStack(spacing: 38) {
                    SessionContentView(model: model)
                        .frame(width: 326)

                    HorizonGardenView(
                        phase: model.phase,
                        progress: model.phase == .completed ? 1 : model.restProgress,
                        appearance: appearance.mode
                    )
                    .frame(width: 354, height: 420)
                }
                .padding(.horizontal, 40)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
        .frame(width: 800, height: 590)
        .preferredColorScheme(appearance.mode.colorScheme)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.8),
            value: model.phase
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.05),
            value: appearance.mode
        )
        .onChange(of: model.phase) { phase in
            if phase == .ready {
                presentReminder()
            } else {
                NotificationManager.shared.clearReminder()
                ReminderPanelController.shared.dismiss()
            }

            if phase == .completed, playGentleSound {
                NSSound(named: NSSound.Name("Tink"))?.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eyesCallerStartRest)) { _ in
            ReminderPanelController.shared.dismiss()
            model.startRest()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .statistics:
                StatisticsView(statistics: statistics, appearance: appearance)
            case .settings:
                SettingsView(appearance: appearance)
            }
        }
        .background(WindowAccessor(appearance: appearance.mode))
    }

    private func presentReminder() {
        let selectedStyle = ReminderStyle(rawValue: reminderStyle) ?? .notificationAndPopup

        if selectedStyle == .notificationAndPopup {
            presentReminderPanel()
        }

        NotificationManager.shared.sendRestReminder { [model] delivered in
            guard model.phase == .ready else { return }
            if !delivered, selectedStyle == .notificationOnly {
                presentReminderPanel()
            }
        }
    }

    private func presentReminderPanel() {
        ReminderPanelController.shared.present(
            appearance: appearance,
            onStart: {
                model.startRest()
                ApplicationVisibility.showMainWindow()
            },
            onSnooze: {
                model.snooze()
            },
            onOpenMainWindow: {
                ApplicationVisibility.showMainWindow()
            }
        )
    }

    private var topBar: some View {
        HStack(spacing: 11) {
            BrandMark()

            VStack(alignment: .leading, spacing: 1) {
                Text("眺眺")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GardenTheme.ink)
                Text("Eyes Caller")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(GardenTheme.mutedInk)
                    .tracking(1.2)
            }

            Spacer()

            StatusPill(phase: model.phase)

            Button {
                appearance.toggleManual()
            } label: {
                Image(systemName: appearance.mode == .day ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .id(appearance.mode)
                    .transition(.scale.combined(with: .opacity))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(appearance.mode == .day ? "切换到夜晚模式" : "切换到白天模式")
            .help(appearance.mode == .day ? "切换到夜晚模式" : "切换到白天模式")

            Button {
                activeSheet = .statistics
            } label: {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("查看远眺足迹")
            .help("远眺足迹")

            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("打开提醒设置")
            .help("提醒设置")
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var ambientShapes: some View {
        GeometryReader { proxy in
            Circle()
                .fill(GardenTheme.ambientGlow)
                .frame(width: 290, height: 290)
                .blur(radius: 2)
                .offset(x: -100, y: proxy.size.height - 180)

            Circle()
                .fill(GardenTheme.sunlight.opacity(model.phase == .completed ? 0.18 : 0.07))
                .frame(width: 240, height: 240)
                .blur(radius: 8)
                .offset(x: proxy.size.width - 130, y: -120)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum RootSheet: String, Identifiable {
    case statistics
    case settings

    var id: String { rawValue }
}

private struct WindowAccessor: NSViewRepresentable {
    let appearance: AppearanceMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.identifier = ApplicationVisibility.mainWindowIdentifier
        window.title = "眺眺"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        coordinator.applyAppearance(appearance, to: window)
        coordinator.window = window
        if let closeButton = window.standardWindowButton(.closeButton) {
            closeButton.target = coordinator
            closeButton.action = #selector(Coordinator.hideMainWindow)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var window: NSWindow?
        private var appliedMode: AppearanceMode?
        private weak var transitionOverlay: NSImageView?
        private nonisolated(unsafe) var appearanceObserver: NSObjectProtocol?
        private nonisolated(unsafe) var displayOptionsObserver: NSObjectProtocol?

        override init() {
            super.init()
            appearanceObserver = NotificationCenter.default.addObserver(
                forName: .eyesCallerAppearanceWillChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.captureBeforeAppearanceChange()
                }
            }
            displayOptionsObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window, let mode = self.appliedMode else { return }
                    self.applyAppearance(mode, to: window)
                }
            }
        }

        deinit {
            if let appearanceObserver {
                NotificationCenter.default.removeObserver(appearanceObserver)
            }
            if let displayOptionsObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(displayOptionsObserver)
            }
        }

        func applyAppearance(_ mode: AppearanceMode, to window: NSWindow) {
            let resolvedAppearance = GardenAppearance.resolved(for: mode)
            let modeChanged = appliedMode != mode
            let appearanceVariantChanged = window.appearance?.name != resolvedAppearance?.name
            guard modeChanged || appearanceVariantChanged else {
                transitionOverlay?.removeFromSuperview()
                return
            }
            window.appearance = resolvedAppearance
            NSApp.appearance = resolvedAppearance
            appliedMode = mode

            guard modeChanged,
                  !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                  let overlay = transitionOverlay else {
                transitionOverlay?.removeFromSuperview()
                return
            }

            // Keep the old frame fully opaque until SwiftUI has committed the
            // first frame of the new theme underneath it. Starting the fade on
            // the next main-loop turn prevents a one-frame color flash.
            DispatchQueue.main.async {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 1.05
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    overlay.animator().alphaValue = 0
                } completionHandler: {
                    Task { @MainActor in
                        overlay.removeFromSuperview()
                    }
                }
            }
        }

        private func captureBeforeAppearanceChange() {
            transitionOverlay?.removeFromSuperview()
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                  let window,
                  window.isVisible,
                  let contentView = window.contentView,
                  let previousImage = snapshot(of: contentView) else { return }

            // Install the old frame before AppearanceController publishes the
            // new mode, so there is never an uncovered frame during the swap.
            let overlay = PassThroughImageView(frame: contentView.bounds)
            overlay.image = previousImage
            overlay.imageScaling = .scaleAxesIndependently
            overlay.autoresizingMask = [.width, .height]
            contentView.addSubview(overlay, positioned: .above, relativeTo: nil)
            transitionOverlay = overlay

            // A coalesced day→night→day update may never call applyAppearance
            // with a different final mode. Always remove an unconsumed snapshot.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self, weak overlay] in
                guard let self, let overlay, self.transitionOverlay === overlay else { return }
                overlay.removeFromSuperview()
            }
        }

        @objc func hideMainWindow() {
            guard let window else { return }
            ApplicationVisibility.hideInMenuBar(window)
        }

        private func snapshot(of view: NSView?) -> NSImage? {
            guard let view, !view.bounds.isEmpty,
                  let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                return nil
            }
            view.cacheDisplay(in: view.bounds, to: representation)
            let image = NSImage(size: view.bounds.size)
            image.addRepresentation(representation)
            return image
        }
    }
}

private final class PassThroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
