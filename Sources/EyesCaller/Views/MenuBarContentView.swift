import AppKit
import SwiftUI

// Keep the native menu structurally stable while it is open. The actions hold
// live model references, but the menu itself does not observe per-second timer
// publications, which would otherwise move AppKit's blue hover highlight.
struct MenuBarContentView: View, Equatable {
    let model: RestSessionModel
    let appearance: AppearanceController

    nonisolated static func == (lhs: MenuBarContentView, rhs: MenuBarContentView) -> Bool {
        true
    }

    var body: some View {
        Text("眺眺正在后台守护双眼")

        Divider()

        Button {
            appearance.toggleManual()
        } label: {
            Label("切换昼夜模式", systemImage: "circle.lefthalf.filled")
        }

        Button {
            ApplicationVisibility.showMainWindow()
        } label: {
            Label("显示眺眺", systemImage: "macwindow")
        }
        .keyboardShortcut("o")

        Button {
            model.startRest()
            ApplicationVisibility.showMainWindow()
        } label: {
            Label("立即远眺", systemImage: "eye")
        }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Label("退出眺眺", systemImage: "power")
        }
        .keyboardShortcut("q")
    }
}

struct MenuBarStatusLabel: View {
    var body: some View {
        Image(nsImage: MenuBarIconAsset.image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("眺眺")
    }
}

@MainActor
private enum MenuBarIconAsset {
    static let image: NSImage = {
        let iconURL = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
            ?? Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png")
        guard let iconURL, let image = NSImage(contentsOf: iconURL) else {
            return NSImage(size: NSSize(width: 18, height: 18))
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
}
