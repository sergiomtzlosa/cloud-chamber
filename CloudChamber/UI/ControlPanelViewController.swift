import AppKit
import UniformTypeIdentifiers

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class ControlPanelViewController: NSViewController {
    var onConfigurationChanged: ((ChamberConfiguration) -> Void)?
    var onResetDefaults: (() -> Void)?
    var onResetCamera: (() -> Void)?

    private var configuration: ChamberConfiguration
    private var isUpdatingControls = false

    private let scrollView = NSScrollView()
    private let documentView = FlippedDocumentView()
    private let stackView = NSStackView()

    private let sourcePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let eventRateSlider = NSSlider()
    private let eventRateValueLabel = NSTextField(labelWithString: "")
    private let fieldSlider = NSSlider()
    private let fieldValueLabel = NSTextField(labelWithString: "")
    private let supersaturationSlider = NSSlider()
    private let supersaturationValueLabel = NSTextField(labelWithString: "")
    private let energySlider = NSSlider()
    private let energyValueLabel = NSTextField(labelWithString: "")
    private let timeScaleSlider = NSSlider()
    private let timeScaleValueLabel = NSTextField(labelWithString: "")
    private let persistenceSlider = NSSlider()
    private let persistenceValueLabel = NSTextField(labelWithString: "")

    private let scatteringButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let cosmicShowersButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let legendButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let statisticsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let mistButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    init(configuration: ChamberConfiguration) {
        self.configuration = configuration.clamped()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.white.cgColor
        view = rootView

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        rootView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        documentView.translatesAutoresizingMaskIntoConstraints = true
        documentView.autoresizingMask = []
        documentView.frame = NSRect(x: 0, y: 0, width: 300, height: 900)
        scrollView.documentView = documentView

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 12
        documentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20)
        ])

        buildControls()
        applyConfigurationToControls()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutDocumentView()
    }

    private func layoutDocumentView() {
        let availableWidth = scrollView.contentSize.width
        guard availableWidth > 0 else { return }

        if abs(documentView.frame.width - availableWidth) > 0.5 {
            documentView.frame.size.width = availableWidth
            documentView.layoutSubtreeIfNeeded()
        }

        let targetHeight = max(
            stackView.fittingSize.height + 40,
            scrollView.contentSize.height
        )
        let targetSize = NSSize(width: availableWidth, height: targetHeight)
        if abs(documentView.frame.width - targetSize.width) > 0.5
            || abs(documentView.frame.height - targetSize.height) > 0.5 {
            documentView.frame = NSRect(origin: .zero, size: targetSize)
        }
    }

    func update(configuration: ChamberConfiguration) {
        self.configuration = configuration.clamped()
        applyConfigurationToControls()
        view.needsLayout = true
    }

    // MARK: - Control construction

    private func buildControls() {
        let title = NSTextField(labelWithString: "Chamber Settings")
        title.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .labelColor
        stackView.addArrangedSubview(title)

        let subtitle = NSTextField(
            wrappingLabelWithString: "Configure the particle source, physics, and chamber display."
        )
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0
        stackView.addArrangedSubview(subtitle)
        subtitle.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        stackView.setCustomSpacing(20, after: subtitle)

        addSectionHeader("Radiation Source")
        addPopupRow(title: "Particle source", popup: sourcePopup)
        configureSourcePopup()

        configureSlider(
            eventRateSlider,
            minimum: 0,
            maximum: 10,
            action: #selector(eventRateChanged(_:))
        )
        let eventRateRow = makeSliderRow(
            title: "Emission rate",
            slider: eventRateSlider,
            valueLabel: eventRateValueLabel
        )
        stackView.addArrangedSubview(eventRateRow)
        eventRateRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        configureCheckbox(
            cosmicShowersButton,
            title: "Include cosmic showers",
            action: #selector(cosmicShowersChanged(_:))
        )
        stackView.addArrangedSubview(cosmicShowersButton)
        stackView.setCustomSpacing(20, after: cosmicShowersButton)

        addSectionHeader("Physics")
        configureSlider(
            fieldSlider,
            minimum: -1.5,
            maximum: 1.5,
            action: #selector(fieldChanged(_:))
        )
        let fieldRow = makeSliderRow(
            title: "Magnetic field",
            slider: fieldSlider,
            valueLabel: fieldValueLabel
        )
        stackView.addArrangedSubview(fieldRow)
        fieldRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        configureSlider(
            energySlider,
            minimum: 0.5,
            maximum: 2.0,
            action: #selector(energyChanged(_:))
        )
        let energyRow = makeSliderRow(
            title: "Particle energy",
            slider: energySlider,
            valueLabel: energyValueLabel
        )
        stackView.addArrangedSubview(energyRow)
        energyRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        configureCheckbox(
            scatteringButton,
            title: "Multiple scattering",
            action: #selector(scatteringChanged(_:))
        )
        stackView.addArrangedSubview(scatteringButton)

        configureSlider(
            timeScaleSlider,
            minimum: 0.25,
            maximum: 2.0,
            action: #selector(timeScaleChanged(_:))
        )
        let timeScaleRow = makeSliderRow(
            title: "Simulation speed",
            slider: timeScaleSlider,
            valueLabel: timeScaleValueLabel
        )
        stackView.addArrangedSubview(timeScaleRow)
        timeScaleRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        stackView.setCustomSpacing(20, after: timeScaleRow)

        addSectionHeader("Chamber")
        configureSlider(
            supersaturationSlider,
            minimum: 0,
            maximum: 1,
            action: #selector(supersaturationChanged(_:))
        )
        let supersaturationRow = makeSliderRow(
            title: "Supersaturation",
            slider: supersaturationSlider,
            valueLabel: supersaturationValueLabel
        )
        stackView.addArrangedSubview(supersaturationRow)
        supersaturationRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        configureSlider(
            persistenceSlider,
            minimum: 0.5,
            maximum: 10,
            action: #selector(persistenceChanged(_:))
        )
        let persistenceRow = makeSliderRow(
            title: "Track persistence",
            slider: persistenceSlider,
            valueLabel: persistenceValueLabel
        )
        stackView.addArrangedSubview(persistenceRow)
        persistenceRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        configureCheckbox(
            mistButton,
            title: "Chamber mist",
            action: #selector(mistChanged(_:))
        )
        stackView.addArrangedSubview(mistButton)
        stackView.setCustomSpacing(20, after: mistButton)

        addSectionHeader("Display")
        configureCheckbox(
            legendButton,
            title: "Show particle legend",
            action: #selector(legendChanged(_:))
        )
        stackView.addArrangedSubview(legendButton)

        configureCheckbox(
            statisticsButton,
            title: "Show statistics",
            action: #selector(statisticsChanged(_:))
        )
        stackView.addArrangedSubview(statisticsButton)
        stackView.setCustomSpacing(20, after: statisticsButton)

        addSectionHeader("Actions")
        let resetCameraButton = NSButton(
            title: "Reset Camera",
            target: self,
            action: #selector(resetCameraPressed(_:))
        )
        resetCameraButton.bezelStyle = .rounded
        resetCameraButton.font = NSFont.systemFont(ofSize: 12)
        resetCameraButton.identifier = NSUserInterfaceItemIdentifier("resetCameraButton")
        resetCameraButton.toolTip = "Reset the 3D camera to its default view"

        let resetButton = NSButton(
            title: "Restore Defaults",
            target: self,
            action: #selector(resetDefaultsPressed(_:))
        )
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: 12)
        resetButton.identifier = NSUserInterfaceItemIdentifier("resetDefaultsButton")
        resetButton.toolTip = "Restore all chamber settings to their defaults"

        let actionRow = NSStackView(views: [resetCameraButton, resetButton])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.distribution = .fillEqually
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(actionRow)
        actionRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        stackView.setCustomSpacing(8, after: actionRow)

        let configurationRow = makeConfigurationActionRow()
        configurationRow.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(configurationRow)
        configurationRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        stackView.setCustomSpacing(16, after: configurationRow)

        let footnote = NSTextField(
            wrappingLabelWithString: "Tracks are a qualitative physics approximation for demonstration."
        )
        footnote.font = NSFont.systemFont(ofSize: 10)
        footnote.textColor = .tertiaryLabelColor
        footnote.maximumNumberOfLines = 0
        stackView.addArrangedSubview(footnote)
        footnote.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func makeConfigurationActionRow() -> NSStackView {
        let exportButton = NSButton(
            title: "Export Config…",
            target: self,
            action: #selector(exportConfiguration(_:))
        )
        exportButton.bezelStyle = .rounded
        exportButton.font = NSFont.systemFont(ofSize: 12)
        exportButton.identifier = NSUserInterfaceItemIdentifier("exportConfigurationButton")
        exportButton.toolTip = "Export the current chamber configuration as JSON"

        let loadButton = NSButton(
            title: "Load Config…",
            target: self,
            action: #selector(loadConfiguration(_:))
        )
        loadButton.bezelStyle = .rounded
        loadButton.font = NSFont.systemFont(ofSize: 12)
        loadButton.identifier = NSUserInterfaceItemIdentifier("loadConfigurationButton")
        loadButton.toolTip = "Load chamber settings from a JSON configuration file"

        let buttonRow = NSStackView(views: [exportButton, loadButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 8
        return buttonRow
    }

    private func addSectionHeader(_ title: String) {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        label.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(label)
        stackView.setCustomSpacing(8, after: label)
    }

    private func addPopupRow(title: String, popup: NSPopUpButton) {
        let container = NSView()
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.controlSize = .regular
        popup.font = NSFont.systemFont(ofSize: 12)

        container.addSubview(label)
        container.addSubview(popup)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),

            popup.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            popup.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            popup.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        stackView.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func makeSliderRow(
        title: String,
        slider: NSSlider,
        valueLabel: NSTextField
    ) -> NSView {
        let container = NSView()
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(slider)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),

            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func configureSlider(
        _ slider: NSSlider,
        minimum: Double,
        maximum: Double,
        action: Selector
    ) {
        slider.minValue = minimum
        slider.maxValue = maximum
        slider.isContinuous = true
        slider.target = self
        slider.action = action
        slider.controlSize = .regular
        slider.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureCheckbox(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 12)
        button.controlSize = .regular
    }

    private func configureSourcePopup() {
        sourcePopup.removeAllItems()
        for source in ParticleSource.allCases {
            sourcePopup.addItem(withTitle: source.title)
            sourcePopup.lastItem?.representedObject = source.rawValue
        }
        sourcePopup.target = self
        sourcePopup.action = #selector(sourceChanged(_:))
        sourcePopup.identifier = NSUserInterfaceItemIdentifier("sourcePopup")
        sourcePopup.setAccessibilityLabel("Particle source")

        eventRateSlider.setAccessibilityLabel("Emission rate")
        fieldSlider.setAccessibilityLabel("Magnetic field")
        supersaturationSlider.setAccessibilityLabel("Supersaturation")
        energySlider.setAccessibilityLabel("Particle energy")
        timeScaleSlider.setAccessibilityLabel("Simulation speed")
        persistenceSlider.setAccessibilityLabel("Track persistence")
    }

    // MARK: - State sync

    private func applyConfigurationToControls() {
        isUpdatingControls = true
        defer { isUpdatingControls = false }

        if let index = ParticleSource.allCases.firstIndex(of: configuration.source) {
            sourcePopup.selectItem(at: index)
        }

        eventRateSlider.doubleValue = configuration.eventsPerSecond
        fieldSlider.doubleValue = configuration.magneticField
        supersaturationSlider.doubleValue = configuration.supersaturation
        energySlider.doubleValue = configuration.energyScale
        timeScaleSlider.doubleValue = configuration.timeScale
        persistenceSlider.doubleValue = configuration.trackPersistence

        cosmicShowersButton.state = configuration.cosmicShowers ? .on : .off
        scatteringButton.state = configuration.multipleScattering ? .on : .off
        legendButton.state = configuration.showLegend ? .on : .off
        statisticsButton.state = configuration.showStatistics ? .on : .off
        mistButton.state = configuration.showMist ? .on : .off

        updateValueLabels()
    }

    private func updateValueLabels() {
        if configuration.eventsPerSecond < 0.05 {
            eventRateValueLabel.stringValue = "Off"
        } else {
            eventRateValueLabel.stringValue = String(format: "%.1f /s", configuration.eventsPerSecond)
        }

        if abs(configuration.magneticField) < 0.05 {
            fieldValueLabel.stringValue = "0.0 T"
        } else {
            fieldValueLabel.stringValue = String(format: "%+.1f T", configuration.magneticField)
        }

        supersaturationValueLabel.stringValue = String(
            format: "%.0f%%",
            configuration.supersaturation * 100
        )
        energyValueLabel.stringValue = String(format: "%.2f×", configuration.energyScale)
        timeScaleValueLabel.stringValue = String(format: "%.2f×", configuration.timeScale)
        persistenceValueLabel.stringValue = String(format: "%.1f s", configuration.trackPersistence)
    }

    private func notifyChange() {
        guard !isUpdatingControls else { return }
        configuration = configuration.clamped()
        updateValueLabels()
        onConfigurationChanged?(configuration)
    }

    // MARK: - Actions

    @objc private func sourceChanged(_ sender: NSPopUpButton) {
        guard
            let rawValue = sender.selectedItem?.representedObject as? String,
            let source = ParticleSource(rawValue: rawValue)
        else { return }
        configuration.source = source
        notifyChange()
    }

    @objc private func eventRateChanged(_ sender: NSSlider) {
        configuration.eventsPerSecond = sender.doubleValue
        notifyChange()
    }

    @objc private func fieldChanged(_ sender: NSSlider) {
        configuration.magneticField = sender.doubleValue
        notifyChange()
    }

    @objc private func supersaturationChanged(_ sender: NSSlider) {
        configuration.supersaturation = sender.doubleValue
        notifyChange()
    }

    @objc private func energyChanged(_ sender: NSSlider) {
        configuration.energyScale = sender.doubleValue
        notifyChange()
    }

    @objc private func timeScaleChanged(_ sender: NSSlider) {
        configuration.timeScale = sender.doubleValue
        notifyChange()
    }

    @objc private func persistenceChanged(_ sender: NSSlider) {
        configuration.trackPersistence = sender.doubleValue
        notifyChange()
    }

    @objc private func cosmicShowersChanged(_ sender: NSButton) {
        configuration.cosmicShowers = sender.state == .on
        notifyChange()
    }

    @objc private func scatteringChanged(_ sender: NSButton) {
        configuration.multipleScattering = sender.state == .on
        notifyChange()
    }

    @objc private func legendChanged(_ sender: NSButton) {
        configuration.showLegend = sender.state == .on
        notifyChange()
    }

    @objc private func statisticsChanged(_ sender: NSButton) {
        configuration.showStatistics = sender.state == .on
        notifyChange()
    }

    @objc private func mistChanged(_ sender: NSButton) {
        configuration.showMist = sender.state == .on
        notifyChange()
    }

    @objc private func resetCameraPressed(_ sender: Any?) {
        onResetCamera?()
    }

    @objc private func resetDefaultsPressed(_ sender: Any?) {
        onResetDefaults?()
    }

    @objc private func exportConfiguration(_ sender: Any?) {
        guard let window = view.window else { return }

        let panel = NSSavePanel()
        panel.title = "Export Chamber Configuration"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "CloudChamber-Configuration.json"

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(self.configuration)
                try data.write(to: url, options: .atomic)
            } catch {
                self.presentFileError(
                    title: "Couldn’t Export Configuration",
                    error: error
                )
            }
        }
    }

    @objc private func loadConfiguration(_ sender: Any?) {
        guard let window = view.window else { return }

        let panel = NSOpenPanel()
        panel.title = "Load Chamber Configuration"
        panel.message = "Choose a CloudChamber JSON configuration file."
        panel.prompt = "Load"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let data = try Data(contentsOf: url)
                let loaded = try JSONDecoder().decode(ChamberConfiguration.self, from: data)
                    .clamped()
                self.configuration = loaded
                self.applyConfigurationToControls()
                self.view.needsLayout = true
                self.onConfigurationChanged?(loaded)
            } catch {
                self.presentFileError(
                    title: "Couldn’t Load Configuration",
                    message: "The selected file isn’t a valid CloudChamber configuration.",
                    error: error
                )
            }
        }
    }

    private func presentFileError(title: String, message: String? = nil, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        if let message {
            alert.informativeText = "\(message)\n\n\(error.localizedDescription)"
        } else {
            alert.informativeText = error.localizedDescription
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        if let window = view.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
