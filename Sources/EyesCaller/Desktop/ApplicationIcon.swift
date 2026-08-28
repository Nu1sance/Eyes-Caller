import AppKit
import Foundation

@MainActor
enum ApplicationIcon {
    private static let image: NSImage? = {
        let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns")
        guard let iconURL else { return nil }
        return NSImage(contentsOf: iconURL)
    }()

    static func apply() {
        guard let image else { return }
        NSApp.applicationIconImage = image
        NSApp.dockTile.display()
    }

    static func applyAfterDockTileRecreation() {
        apply()
        DispatchQueue.main.async {
            apply()
        }
    }
}
