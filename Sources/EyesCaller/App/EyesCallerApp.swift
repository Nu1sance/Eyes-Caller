import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        ApplicationIcon.applyAfterDockTileRecreation()

        NotificationManager.shared.configure()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct EyesCallerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: RestSessionModel
    @StateObject private var statistics: EyeCareStatisticsStore
    @StateObject private var appearance: AppearanceController

    init() {
        let statistics = EyeCareStatisticsStore()
        let appearance = AppearanceController()
        _statistics = StateObject(wrappedValue: statistics)
        _appearance = StateObject(wrappedValue: appearance)
        _model = StateObject(
            wrappedValue: RestSessionModel(statisticsStore: statistics)
        )
    }

    var body: some Scene {
        Window("眺眺", id: "main") {
            EyesCallerRootView(
                model: model,
                statistics: statistics,
                appearance: appearance
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 590)

        MenuBarExtra {
            MenuBarContentView(model: model, appearance: appearance)
                .equatable()
                .preferredColorScheme(appearance.mode.colorScheme)
        } label: {
            MenuBarStatusLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}
