import AppKit
import CoreGraphics

final class MainViewController: NSViewController {
    private(set) var configuration: ChamberConfiguration
    private(set) var isSimulationRunning = true

    var onRunningStateChanged: ((Bool) -> Void)?

    private let engine: SimulationEngine
    private let controlPanel: ControlPanelViewController
    private let chamberView = ChamberSceneView()
    private var timer: Timer?
    private var lastTickTime = ProcessInfo.processInfo.systemUptime

    init(configuration: ChamberConfiguration) {
        let loadedConfiguration = configuration.clamped()
        self.configuration = loadedConfiguration
        engine = SimulationEngine(
            configuration: loadedConfiguration,
            seed: UInt64.random(in: 1...UInt64.max)
        )
        controlPanel = ControlPanelViewController(configuration: loadedConfiguration)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.white.cgColor
        view = rootView

        addChild(controlPanel)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        chamberView.translatesAutoresizingMaskIntoConstraints = false
        chamberView.configuration = configuration
        chamberView.isRunning = isSimulationRunning

        let panelView = controlPanel.view
        panelView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(chamberView)
        rootView.addSubview(divider)
        rootView.addSubview(panelView)

        NSLayoutConstraint.activate([
            chamberView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            chamberView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 16),
            chamberView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -16),
            chamberView.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -20),

            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: rootView.topAnchor),
            divider.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            divider.trailingAnchor.constraint(equalTo: panelView.leadingAnchor),

            panelView.widthAnchor.constraint(equalToConstant: 300),
            panelView.topAnchor.constraint(equalTo: rootView.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            panelView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        controlPanel.onConfigurationChanged = { [weak self] newConfiguration in
            self?.applyConfiguration(newConfiguration)
        }
        controlPanel.onResetDefaults = { [weak self] in
            self?.resetDefaults(nil)
        }
        controlPanel.onResetCamera = { [weak self] in
            self?.chamberView.resetCamera()
        }

        publishEngineState()
        startAnimationTimer()
    }

    private func startAnimationTimer() {
        lastTickTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard isSimulationRunning else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastTickTime
        lastTickTime = now
        guard elapsed > 0 else { return }

        engine.update(dt: elapsed)
        chamberView.tracks = engine.tracks
        chamberView.statistics = engine.statistics
        chamberView.needsDisplay = true
    }

    private func publishEngineState() {
        chamberView.tracks = engine.tracks
        chamberView.statistics = engine.statistics
        chamberView.configuration = configuration
        chamberView.isRunning = isSimulationRunning
        chamberView.needsDisplay = true
    }

    private func applyConfiguration(_ newConfiguration: ChamberConfiguration) {
        let clamped = newConfiguration.clamped()
        configuration = clamped
        engine.configuration = clamped
        chamberView.configuration = clamped
        clamped.save()
        chamberView.needsDisplay = true
    }

    // MARK: - Actions

    @objc func toggleSimulation(_ sender: Any?) {
        isSimulationRunning.toggle()
        lastTickTime = ProcessInfo.processInfo.systemUptime
        chamberView.isRunning = isSimulationRunning
        chamberView.needsDisplay = true
        onRunningStateChanged?(isSimulationRunning)
    }

    @objc func clearTracks(_ sender: Any?) {
        engine.clearTracks()
        publishEngineState()
    }

    @objc func resetDefaults(_ sender: Any?) {
        let defaults = ChamberConfiguration.default
        configuration = defaults
        defaults.save()
        controlPanel.update(configuration: defaults)
        engine.configuration = defaults
        engine.reset(seed: UInt64.random(in: 1...UInt64.max))
        lastTickTime = ProcessInfo.processInfo.systemUptime
        publishEngineState()
        chamberView.resetCamera()
    }
}
