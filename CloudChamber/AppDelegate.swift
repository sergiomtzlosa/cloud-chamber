import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)

        let controller = MainWindowController(configuration: ChamberConfiguration.load())
        windowController = controller

        buildMainMenu()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu actions

    @objc private func toggleSimulationFromMenu(_ sender: Any?) {
        windowController?.mainViewController.toggleSimulation(sender)
    }

    @objc private func clearTracksFromMenu(_ sender: Any?) {
        windowController?.mainViewController.clearTracks(sender)
    }

    @objc private func resetDefaultsFromMenu(_ sender: Any?) {
        windowController?.mainViewController.resetDefaults(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let controller = windowController else { return false }
        switch menuItem.action {
        case #selector(toggleSimulationFromMenu(_:)):
            menuItem.title = controller.mainViewController.isSimulationRunning
                ? "Pause Simulation"
                : "Resume Simulation"
            return true
        case #selector(clearTracksFromMenu(_:)):
            menuItem.title = "Clear Tracks"
            return true
        case #selector(resetDefaultsFromMenu(_:)):
            menuItem.title = "Reset to Defaults"
            return true
        default:
            return true
        }
    }

    // MARK: - Main menu

    private func buildMainMenu() {
        let appName = "Cloud Chamber"
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "CloudChamber")
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )

        let simulationMenuItem = NSMenuItem()
        mainMenu.addItem(simulationMenuItem)
        let simulationMenu = NSMenu(title: "Simulation")
        simulationMenuItem.submenu = simulationMenu

        let toggleItem = simulationMenu.addItem(
            withTitle: "Pause Simulation",
            action: #selector(toggleSimulationFromMenu(_:)),
            keyEquivalent: " "
        )
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = []

        let clearItem = simulationMenu.addItem(
            withTitle: "Clear Tracks",
            action: #selector(clearTracksFromMenu(_:)),
            keyEquivalent: "k"
        )
        clearItem.target = self

        let resetItem = simulationMenu.addItem(
            withTitle: "Reset to Defaults",
            action: #selector(resetDefaultsFromMenu(_:)),
            keyEquivalent: "r"
        )
        resetItem.target = self

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}
