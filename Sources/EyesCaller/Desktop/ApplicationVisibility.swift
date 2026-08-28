import AppKit

@MainActor
enum ApplicationVisibility {
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("EyesCallerMainWindow")

    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        ApplicationIcon.applyAfterDockTileRecreation()
        NSApp.activate(ignoringOtherApps: true)

        guard let window = mainWindow else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    static func hideInMenuBar(_ window: NSWindow) {
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    static var mainWindow: NSWindow? {
        NSApp.windows.first { window in
            window.identifier == mainWindowIdentifier
        }
    }
}
