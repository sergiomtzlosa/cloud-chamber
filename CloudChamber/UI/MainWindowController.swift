import AppKit

private extension NSToolbarItem.Identifier {
    static let toggleSimulation = NSToolbarItem.Identifier("CloudChamber.toggleSimulation")
    static let clearTracks = NSToolbarItem.Identifier("CloudChamber.clearTracks")
    static let resetDefaults = NSToolbarItem.Identifier("CloudChamber.resetDefaults")
}

final class MainWindowController: NSWindowController, NSToolbarDelegate {
    let mainViewController: MainViewController
    private var pauseToolbarItem: NSToolbarItem?

    init(configuration: ChamberConfiguration) {
        mainViewController = MainViewController(configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cloud Chamber"
        window.subtitle = "Interactive 3D particle track simulator"
        window.minSize = NSSize(width: 920, height: 620)
        window.backgroundColor = .white
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed

        super.init(window: window)

        window.contentViewController = mainViewController
        let autosaveName = "CloudChamberMainWindow"
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)

        let toolbar = NSToolbar(identifier: "CloudChamberToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        mainViewController.onRunningStateChanged = { [weak self] isRunning in
            self?.updatePauseItem(isRunning: isRunning)
        }
        updatePauseItem(isRunning: mainViewController.isSimulationRunning)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updatePauseItem(isRunning: Bool) {
        guard let item = pauseToolbarItem else { return }
        let symbolName = isRunning ? "pause.fill" : "play.fill"
        let description = isRunning ? "Pause simulation" : "Resume simulation"
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        item.label = isRunning ? "Pause" : "Resume"
        item.toolTip = description
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSimulation, .clearTracks, .resetDefaults, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSimulation, .clearTracks, .resetDefaults, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleSimulation:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = mainViewController
            item.action = #selector(MainViewController.toggleSimulation(_:))
            item.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause simulation")
            item.label = "Pause"
            item.toolTip = "Pause simulation (Space)"
            item.isNavigational = false
            pauseToolbarItem = item
            return item

        case .clearTracks:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = mainViewController
            item.action = #selector(MainViewController.clearTracks(_:))
            item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear tracks")
            item.label = "Clear"
            item.toolTip = "Clear all tracks (⌘K)"
            return item

        case .resetDefaults:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = mainViewController
            item.action = #selector(MainViewController.resetDefaults(_:))
            item.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Reset defaults")
            item.label = "Reset"
            item.toolTip = "Restore default chamber settings (⌘R)"
            return item

        default:
            return nil
        }
    }
}
