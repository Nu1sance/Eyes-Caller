import AppKit
import SwiftUI

@MainActor
final class ReminderPanelController {
    static let shared = ReminderPanelController()

    private var panel: ReminderPanel?

    private init() {}

    func present(
        appearance: AppearanceController,
        onStart: @escaping () -> Void,
        onSnooze: @escaping () -> Void,
        onOpenMainWindow: @escaping () -> Void
    ) {
        dismiss()

        let content = CompactReminderView(
            appearance: appearance,
            onStart: { [weak self] in
                self?.dismiss()
                onStart()
            },
            onSnooze: { [weak self] in
                self?.dismiss()
                onSnooze()
            },
            onOpenMainWindow: { [weak self] in
                self?.dismiss()
                onOpenMainWindow()
            }
        )

        let panel = ReminderPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 238),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: content)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = GardenAppearance.resolved(for: appearance.mode)
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        positionAtTopRight(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func positionAtTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 24
        panel.setFrameOrigin(
            NSPoint(
                x: visibleFrame.maxX - panel.frame.width - margin,
                y: visibleFrame.maxY - panel.frame.height - margin
            )
        )
    }
}

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
