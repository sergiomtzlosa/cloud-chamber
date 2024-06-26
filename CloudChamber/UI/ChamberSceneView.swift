import AppKit
import SceneKit
import simd

private final class TrackVisual {
    let container = SCNNode()
    let coreNode = SCNNode()
    let haloNode = SCNNode()
    let coreMaterial: SCNMaterial
    let haloMaterial: SCNMaterial
    var markerMaterials: [SCNMaterial] = []
    var renderedPointCount = -1

    init(kind: ParticleKind) {
        coreMaterial = SCNMaterial()
        coreMaterial.lightingModel = .constant
        coreMaterial.diffuse.contents = kind.color
        coreMaterial.emission.contents = kind.color
        coreMaterial.isDoubleSided = true
        coreMaterial.blendMode = .alpha
        coreMaterial.writesToDepthBuffer = true
        coreMaterial.readsFromDepthBuffer = true

        haloMaterial = SCNMaterial()
        haloMaterial.lightingModel = .constant
        haloMaterial.diffuse.contents = kind.color
        haloMaterial.emission.contents = kind.color
        haloMaterial.isDoubleSided = true
        haloMaterial.blendMode = .alpha
        haloMaterial.writesToDepthBuffer = false
        haloMaterial.readsFromDepthBuffer = true

        coreNode.renderingOrder = 10
        haloNode.renderingOrder = 9
        container.addChildNode(haloNode)
        container.addChildNode(coreNode)
        container.name = "Track"
    }
}

final class ChamberSceneView: NSView {
    var configuration = ChamberConfiguration.default {
        didSet { applyConfiguration() }
    }

    var tracks: [ParticleTrack] = [] {
        didSet { syncTrackVisuals() }
    }

    var statistics = SimulationStatistics() {
        didSet { overlayView.statistics = statistics }
    }

    var isRunning = true {
        didSet { overlayView.isRunning = isRunning }
    }

    private let sceneView = SCNView()
    private let overlayView = ChamberOverlayView()
    private let scene = SCNScene()
    private let chamberRoot = SCNNode()
    private let trackRoot = SCNNode()
    private let mistRoot = SCNNode()
    private let sourceRoot = SCNNode()
    private let cameraNode = SCNNode()
    private var trackVisuals: [UUID: TrackVisual] = [:]
    private var needsFullTrackRefresh = true

    private let cameraTarget = SCNVector3(x: 0, y: 0.0, z: 0)
    private let initialCameraPosition = SCNVector3(x: 3.5, y: 2.8, z: 4.2)
    private static let conversionColor = NSColor(
        calibratedRed: 0.16,
        green: 0.47,
        blue: 0.33,
        alpha: 1
    )

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureContainer()
        configureSceneView()
        configureOverlay()
        buildScene()
        applyConfiguration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor(calibratedWhite: 0, alpha: 0.13).cgColor
    }

    func resetCamera() {
        cameraNode.position = initialCameraPosition
        cameraNode.look(
            at: cameraTarget,
            up: SCNVector3(x: 0, y: 1, z: 0),
            localFront: SCNVector3(x: 0, y: 0, z: -1)
        )
        sceneView.pointOfView = cameraNode
        sceneView.defaultCameraController.target = cameraTarget
    }

    // MARK: - Setup

    private func configureContainer() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedWhite: 0, alpha: 0.13).cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Interactive 3D cloud chamber")
    }

    private func configureSceneView() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.scene = scene
        sceneView.backgroundColor = .white
        sceneView.antialiasingMode = .multisampling4X
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.isPlaying = true
        sceneView.rendersContinuously = true
        sceneView.preferredFramesPerSecond = 60
        addSubview(sceneView)

        NSLayoutConstraint.activate([
            sceneView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneView.topAnchor.constraint(equalTo: topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let controller = sceneView.defaultCameraController
        controller.interactionMode = .orbitTurntable
        controller.inertiaEnabled = true
        controller.target = cameraTarget
    }

    private func configureOverlay() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func buildScene() {
        scene.background.contents = NSColor(calibratedWhite: 0.975, alpha: 1)
        scene.lightingEnvironment.contents = Self.makeLightingEnvironmentImage()
        scene.lightingEnvironment.intensity = 0.35

        cameraNode.camera = makeCamera()
        cameraNode.position = initialCameraPosition
        cameraNode.look(
            at: cameraTarget,
            up: SCNVector3(x: 0, y: 1, z: 0),
            localFront: SCNVector3(x: 0, y: 0, z: -1)
        )
        scene.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode

        scene.rootNode.addChildNode(chamberRoot)
        chamberRoot.addChildNode(trackRoot)
        chamberRoot.addChildNode(mistRoot)
        chamberRoot.addChildNode(sourceRoot)

        buildStudioFloor()
        buildChamberBody()
        buildMist()
        buildSource()
        buildLights()
    }

    private func makeCamera() -> SCNCamera {
        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.05
        camera.zFar = 60
        camera.wantsHDR = false
        camera.exposureOffset = 0
        camera.contrast = 0.04
        camera.saturation = 1.06
        return camera
    }

    private func buildStudioFloor() {
        let platform = SCNCylinder(radius: 1.72, height: 0.035)
        platform.radialSegmentCount = 128
        platform.firstMaterial = makeMaterial(
            color: NSColor(calibratedWhite: 0.955, alpha: 1),
            metalness: 0,
            roughness: 0.55
        )
        let platformNode = SCNNode(geometry: platform)
        platformNode.name = "StudioPlatform"
        platformNode.position = SCNVector3(x: 0, y: -0.80, z: 0)
        scene.rootNode.addChildNode(platformNode)

        let softShadow = SCNPlane(width: 3.4, height: 3.4)
        softShadow.firstMaterial = SCNMaterial()
        softShadow.firstMaterial?.lightingModel = .constant
        softShadow.firstMaterial?.diffuse.contents = Self.makeSoftShadowImage()
        softShadow.firstMaterial?.transparency = 0.30
        softShadow.firstMaterial?.isDoubleSided = true
        softShadow.firstMaterial?.writesToDepthBuffer = false
        let shadowNode = SCNNode(geometry: softShadow)
        shadowNode.name = "SoftShadow"
        shadowNode.eulerAngles = SCNVector3(x: -CGFloat.pi / 2, y: 0, z: 0)
        shadowNode.position = SCNVector3(x: 0, y: -0.781, z: 0)
        shadowNode.renderingOrder = 1
        scene.rootNode.addChildNode(shadowNode)
    }

    private func buildChamberBody() {
        let aluminum = makeMaterial(
            color: NSColor(calibratedRed: 0.50, green: 0.53, blue: 0.56, alpha: 1),
            metalness: 0.9,
            roughness: 0.22
        )
        let darkMetal = makeMaterial(
            color: NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.26, alpha: 1),
            metalness: 0.78,
            roughness: 0.28
        )
        let glass = makeGlassMaterial()
        let coldPlateMaterial = makeMaterial(
            color: NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.31, alpha: 1),
            metalness: 0.7,
            roughness: 0.36
        )

        let base = SCNCylinder(radius: 1.36, height: 0.17)
        base.radialSegmentCount = 96
        base.firstMaterial = aluminum
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(x: 0, y: -0.695, z: 0)
        chamberRoot.addChildNode(baseNode)

        let baseTrim = SCNTorus(ringRadius: 1.29, pipeRadius: 0.028)
        baseTrim.ringSegmentCount = 96
        baseTrim.pipeSegmentCount = 18
        baseTrim.firstMaterial = darkMetal
        let baseTrimNode = SCNNode(geometry: baseTrim)
        baseTrimNode.position = SCNVector3(x: 0, y: -0.778, z: 0)
        chamberRoot.addChildNode(baseTrimNode)

        for index in 0..<8 {
            let angle = CGFloat(index) * 2 * CGFloat.pi / 8
            let foot = SCNCylinder(radius: 0.045, height: 0.022)
            foot.radialSegmentCount = 24
            foot.firstMaterial = darkMetal
            let footNode = SCNNode(geometry: foot)
            footNode.position = SCNVector3(
                x: cos(angle) * 0.92,
                y: -0.792,
                z: sin(angle) * 0.92
            )
            chamberRoot.addChildNode(footNode)
        }

        let upperBevel = SCNTorus(ringRadius: 1.12, pipeRadius: 0.038)
        upperBevel.ringSegmentCount = 96
        upperBevel.pipeSegmentCount = 18
        upperBevel.firstMaterial = darkMetal
        let upperBevelNode = SCNNode(geometry: upperBevel)
        upperBevelNode.position = SCNVector3(x: 0, y: -0.605, z: 0)
        chamberRoot.addChildNode(upperBevelNode)

        let coldPlate = SCNCylinder(radius: 1.045, height: 0.045)
        coldPlate.radialSegmentCount = 96
        coldPlate.firstMaterial = coldPlateMaterial
        let coldPlateNode = SCNNode(geometry: coldPlate)
        coldPlateNode.position = SCNVector3(x: 0, y: -0.575, z: 0)
        chamberRoot.addChildNode(coldPlateNode)

        let frost = SCNCylinder(radius: 1.025, height: 0.003)
        frost.radialSegmentCount = 96
        frost.firstMaterial = makeFrostMaterial()
        let frostNode = SCNNode(geometry: frost)
        frostNode.name = "Frost"
        frostNode.position = SCNVector3(x: 0, y: -0.551, z: 0)
        chamberRoot.addChildNode(frostNode)

        let glassTube = SCNTube(innerRadius: 1.07, outerRadius: 1.115, height: 1.16)
        glassTube.radialSegmentCount = 96
        glassTube.firstMaterial = glass
        let glassNode = SCNNode(geometry: glassTube)
        glassNode.name = "Glass"
        glassNode.position = SCNVector3(x: 0, y: 0.02, z: 0)
        glassNode.renderingOrder = 50
        chamberRoot.addChildNode(glassNode)

        for y in [-0.55, 0.60] {
            let rim = SCNTorus(ringRadius: 1.115, pipeRadius: 0.035)
            rim.ringSegmentCount = 96
            rim.pipeSegmentCount = 18
            rim.firstMaterial = aluminum
            let rimNode = SCNNode(geometry: rim)
            rimNode.position = SCNVector3(x: 0, y: y, z: 0)
            chamberRoot.addChildNode(rimNode)
        }

        let lid = SCNCylinder(radius: 1.115, height: 0.018)
        lid.radialSegmentCount = 96
        lid.firstMaterial = glass
        let lidNode = SCNNode(geometry: lid)
        lidNode.name = "GlassLid"
        lidNode.position = SCNVector3(x: 0, y: 0.612, z: 0)
        lidNode.renderingOrder = 49
        chamberRoot.addChildNode(lidNode)

        let lidRing = SCNTorus(ringRadius: 1.055, pipeRadius: 0.028)
        lidRing.ringSegmentCount = 96
        lidRing.pipeSegmentCount = 16
        lidRing.firstMaterial = darkMetal
        let lidRingNode = SCNNode(geometry: lidRing)
        lidRingNode.position = SCNVector3(x: 0, y: 0.625, z: 0)
        chamberRoot.addChildNode(lidRingNode)

        let valveStem = SCNCylinder(radius: 0.095, height: 0.09)
        valveStem.radialSegmentCount = 40
        valveStem.firstMaterial = aluminum
        let valveStemNode = SCNNode(geometry: valveStem)
        valveStemNode.position = SCNVector3(x: 0, y: 0.672, z: 0)
        chamberRoot.addChildNode(valveStemNode)

        let valveHandle = SCNTorus(ringRadius: 0.11, pipeRadius: 0.018)
        valveHandle.ringSegmentCount = 40
        valveHandle.pipeSegmentCount = 12
        valveHandle.firstMaterial = darkMetal
        let valveHandleNode = SCNNode(geometry: valveHandle)
        valveHandleNode.position = SCNVector3(x: 0, y: 0.725, z: 0)
        valveHandleNode.eulerAngles = SCNVector3(x: CGFloat.pi / 2, y: 0, z: 0)
        chamberRoot.addChildNode(valveHandleNode)

        for index in 0..<10 {
            let angle = CGFloat(index) * 2 * CGFloat.pi / 10
            let bolt = SCNCylinder(radius: 0.016, height: 0.012)
            bolt.radialSegmentCount = 18
            bolt.firstMaterial = darkMetal
            let boltNode = SCNNode(geometry: bolt)
            boltNode.position = SCNVector3(
                x: cos(angle) * 1.19,
                y: -0.605,
                z: sin(angle) * 1.19
            )
            chamberRoot.addChildNode(boltNode)
        }
    }

    private func buildMist() {
        let texture = Self.makeMistTexture()
        let levels: [(height: CGFloat, size: CGFloat, opacity: CGFloat)] = [
            (-0.535, 2.0, 0.42),
            (-0.43, 1.9, 0.28),
            (-0.29, 1.75, 0.17),
            (-0.12, 1.6, 0.10)
        ]

        for (index, level) in levels.enumerated() {
            let plane = SCNPlane(width: level.size, height: level.size)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = texture
            material.transparency = level.opacity
            material.isDoubleSided = true
            material.blendMode = .alpha
            material.writesToDepthBuffer = false
            material.readsFromDepthBuffer = true
            plane.firstMaterial = material

            let node = SCNNode(geometry: plane)
            node.eulerAngles = SCNVector3(x: -CGFloat.pi / 2, y: 0, z: 0)
            node.position = SCNVector3(x: 0, y: level.height, z: 0)
            node.renderingOrder = 20 + index
            node.opacity = 1

            let rise = SCNAction.moveBy(x: 0, y: 0.035, z: 0, duration: 6.0 + Double(index))
            let fall = rise.reversed()
            node.runAction(.repeatForever(.sequence([rise, fall])))
            mistRoot.addChildNode(node)
        }
    }

    private func buildSource() {
        sourceRoot.position = SCNVector3(
            x: CGFloat(ChamberGeometry.sourcePosition.x),
            y: CGFloat(ChamberGeometry.sourcePosition.y),
            z: CGFloat(ChamberGeometry.sourcePosition.z)
        )

        let brass = makeMaterial(
            color: NSColor(calibratedRed: 0.55, green: 0.40, blue: 0.16, alpha: 1),
            metalness: 0.76,
            roughness: 0.28
        )

        let pedestal = SCNCylinder(radius: 0.075, height: 0.035)
        pedestal.radialSegmentCount = 32
        pedestal.firstMaterial = brass
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(x: 0, y: -0.06, z: 0)
        sourceRoot.addChildNode(pedestalNode)

        let beadMaterial = SCNMaterial()
        beadMaterial.lightingModel = .constant
        beadMaterial.diffuse.contents = NSColor(calibratedRed: 0.94, green: 0.38, blue: 0.12, alpha: 1)
        beadMaterial.emission.contents = NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.04, alpha: 1)
        let bead = SCNSphere(radius: 0.023)
        bead.segmentCount = 32
        bead.firstMaterial = beadMaterial
        let beadNode = SCNNode(geometry: bead)
        beadNode.position = SCNVector3(x: 0, y: 0, z: 0)
        sourceRoot.addChildNode(beadNode)

        let haloMaterial = SCNMaterial()
        haloMaterial.lightingModel = .constant
        haloMaterial.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.08, alpha: 0.12)
        haloMaterial.blendMode = .alpha
        haloMaterial.writesToDepthBuffer = false
        let halo = SCNSphere(radius: 0.052)
        halo.segmentCount = 32
        halo.firstMaterial = haloMaterial
        let haloNode = SCNNode(geometry: halo)
        sourceRoot.addChildNode(haloNode)

        let pulseUp = SCNAction.scale(to: 1.12, duration: 1.8)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SCNAction.scale(to: 1.0, duration: 1.8)
        pulseDown.timingMode = .easeInEaseOut
        haloNode.runAction(.repeatForever(.sequence([pulseUp, pulseDown])))

        let glow = SCNLight()
        glow.type = .omni
        glow.color = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.1, alpha: 1)
        glow.intensity = 9
        glow.attenuationStartDistance = 0.06
        glow.attenuationEndDistance = 0.42
        let glowNode = SCNNode()
        glowNode.light = glow
        sourceRoot.addChildNode(glowNode)
    }

    private func buildLights() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(calibratedWhite: 1.0, alpha: 1)
        ambient.intensity = 175
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let keyLight = SCNLight()
        keyLight.type = .spot
        keyLight.color = NSColor(calibratedRed: 1.0, green: 0.985, blue: 0.95, alpha: 1)
        keyLight.intensity = 680
        keyLight.spotInnerAngle = 32
        keyLight.spotOuterAngle = 78
        keyLight.castsShadow = true
        keyLight.shadowSampleCount = 16
        keyLight.shadowRadius = 9
        keyLight.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.22)
        keyLight.attenuationStartDistance = 2
        keyLight.attenuationEndDistance = 14
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(x: -3.1, y: 5.2, z: 3.8)
        keyNode.look(
            at: SCNVector3(x: 0, y: -0.1, z: 0),
            up: SCNVector3(x: 0, y: 1, z: 0),
            localFront: SCNVector3(x: 0, y: 0, z: -1)
        )
        scene.rootNode.addChildNode(keyNode)

        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.color = NSColor(calibratedRed: 0.82, green: 0.89, blue: 1.0, alpha: 1)
        fillLight.intensity = 240
        fillLight.attenuationStartDistance = 2
        fillLight.attenuationEndDistance = 12
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(x: -4.0, y: 2.0, z: 0.5)
        scene.rootNode.addChildNode(fillNode)

        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.color = NSColor(calibratedRed: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        rimLight.intensity = 380
        rimLight.attenuationStartDistance = 2
        rimLight.attenuationEndDistance = 12
        let rimNode = SCNNode()
        rimNode.light = rimLight
        rimNode.position = SCNVector3(x: 1.8, y: 2.8, z: -3.6)
        scene.rootNode.addChildNode(rimNode)
    }

    private func makeMaterial(
        color: NSColor,
        metalness: CGFloat,
        roughness: CGFloat
    ) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = metalness
        material.roughness.contents = roughness
        return material
    }

    private func makeGlassMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = NSColor(calibratedRed: 0.90, green: 0.95, blue: 0.97, alpha: 1)
        material.specular.contents = NSColor(calibratedWhite: 1.0, alpha: 1)
        material.specular.intensity = 0.8
        material.shininess = 1.4
        material.transparency = 0.07
        material.transparencyMode = .dualLayer
        material.isDoubleSided = true
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.fresnelExponent = 2.0
        return material
    }

    private func makeFrostMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = NSColor(calibratedRed: 0.27, green: 0.33, blue: 0.38, alpha: 1)
        material.metalness.contents = 0.10
        material.roughness.contents = 0.82
        material.transparency = 0.96
        return material
    }

    // MARK: - Configuration and tracks

    private func applyConfiguration() {
        overlayView.configuration = configuration
        mistRoot.isHidden = !configuration.showMist
        sourceRoot.isHidden = !configuration.source.usesSourceMarker
        overlayView.isRunning = isRunning
        needsFullTrackRefresh = true
    }

    private func syncTrackVisuals() {
        let currentIDs = Set(tracks.map(\.id))

        for id in Array(trackVisuals.keys) where !currentIDs.contains(id) {
            trackVisuals[id]?.container.removeFromParentNode()
            trackVisuals.removeValue(forKey: id)
        }

        let supersaturation = configuration.supersaturation
        let widthFactor = 0.88 + supersaturation * 0.28
        let alphaFactor = 0.18 + supersaturation * 0.82

        for track in tracks {
            let visual: TrackVisual
            if let existing = trackVisuals[track.id] {
                visual = existing
            } else {
                visual = makeTrackVisual(for: track)
                trackVisuals[track.id] = visual
            }

            let renderedPoints = renderablePoints(for: track)
            let coreRadius = Double(track.kind.lineWidth) * 0.0036 * widthFactor

            if needsFullTrackRefresh || visual.renderedPointCount != renderedPoints.count {
                rebuildTrackGeometry(
                    visual,
                    points: renderedPoints,
                    coreRadius: coreRadius
                )
                visual.renderedPointCount = renderedPoints.count
            }

            let fade = track.isActive ? 1.0 : max(0, 1 - track.fadeProgress)
            let opacity = CGFloat(Double(track.kind.baseOpacity) * alphaFactor * fade)
            visual.coreMaterial.transparency = opacity
            visual.haloMaterial.transparency = opacity * 0.18
            for material in visual.markerMaterials {
                material.transparency = max(0.18, opacity * 0.9)
            }
        }

        needsFullTrackRefresh = false
    }

    private func makeTrackVisual(for track: ParticleTrack) -> TrackVisual {
        let visual = TrackVisual(kind: track.kind)
        trackRoot.addChildNode(visual.container)

        if track.drawsConversionVertex, let vertex = track.points.first {
            let markerMaterial = SCNMaterial()
            markerMaterial.lightingModel = .constant
            markerMaterial.diffuse.contents = Self.conversionColor
            markerMaterial.emission.contents = Self.conversionColor
            markerMaterial.blendMode = .alpha
            markerMaterial.writesToDepthBuffer = false

            let markerGroup = SCNNode()
            markerGroup.position = scnVector(vertex)

            let sphere = SCNSphere(radius: 0.018)
            sphere.segmentCount = 20
            sphere.firstMaterial = markerMaterial
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.renderingOrder = 12
            markerGroup.addChildNode(sphereNode)

            let ringGeometry = SCNTorus(ringRadius: 0.045, pipeRadius: 0.0035)
            ringGeometry.ringSegmentCount = 32
            ringGeometry.pipeSegmentCount = 8
            ringGeometry.firstMaterial = markerMaterial

            let ringOne = SCNNode(geometry: ringGeometry)
            ringOne.renderingOrder = 12
            markerGroup.addChildNode(ringOne)

            let ringTwo = SCNNode(geometry: ringGeometry)
            ringTwo.eulerAngles = SCNVector3(x: CGFloat.pi / 2, y: 0, z: 0)
            ringTwo.renderingOrder = 12
            markerGroup.addChildNode(ringTwo)

            visual.markerMaterials = [markerMaterial]
            visual.container.addChildNode(markerGroup)
        }

        return visual
    }

    private func rebuildTrackGeometry(
        _ visual: TrackVisual,
        points: [SIMD3<Double>],
        coreRadius: Double
    ) {
        guard points.count >= 2, coreRadius > 0 else {
            visual.coreNode.geometry = nil
            visual.haloNode.geometry = nil
            return
        }

        visual.coreNode.geometry = makeTubeGeometry(
            points: points,
            radius: coreRadius,
            material: visual.coreMaterial
        )
        visual.haloNode.geometry = makeTubeGeometry(
            points: points,
            radius: coreRadius * 3.0,
            material: visual.haloMaterial
        )
    }

    private func renderablePoints(for track: ParticleTrack) -> [SIMD3<Double>] {
        var result: [SIMD3<Double>] = []
        result.reserveCapacity(track.points.count)

        for point in track.points where ChamberGeometry.isInside(point, inset: -0.004) {
            if let previous = result.last, simd_distance(previous, point) < 0.003 {
                continue
            }
            result.append(point)
        }

        guard result.count > 2 else { return result }
        let maximumPoints = 180
        guard result.count > maximumPoints else { return result }

        let step = Int(ceil(Double(result.count) / Double(maximumPoints)))
        var simplified: [SIMD3<Double>] = []
        simplified.reserveCapacity(maximumPoints)
        for index in Swift.stride(from: 0, to: result.count, by: step) {
            simplified.append(result[index])
        }
        if let last = result.last,
           let simplifiedLast = simplified.last,
           simd_distance(last, simplifiedLast) > 0.0005 {
            simplified.append(last)
        }
        return simplified
    }

    private func makeTubeGeometry(
        points: [SIMD3<Double>],
        radius: Double,
        material: SCNMaterial,
        sides: Int = 6
    ) -> SCNGeometry? {
        guard points.count >= 2, radius > 0 else { return nil }

        var vertices: [SCNVector3] = []
        vertices.reserveCapacity(points.count * sides)
        var indices: [UInt32] = []
        indices.reserveCapacity((points.count - 1) * sides * 6)

        var previousNormal: SIMD3<Double>?
        let up = SIMD3<Double>(0, 1, 0)

        for (index, point) in points.enumerated() {
            let tangent: SIMD3<Double>
            if index == 0 {
                tangent = safeNormalize(points[1] - points[0])
            } else if index == points.count - 1 {
                tangent = safeNormalize(points[index] - points[index - 1])
            } else {
                tangent = safeNormalize(points[index + 1] - points[index - 1])
            }

            let normal: SIMD3<Double>
            if let previous = previousNormal {
                var projected = previous - tangent * simd_dot(previous, tangent)
                if simd_length(projected) < 0.0001 {
                    let reference = abs(tangent.y) > 0.92 ? SIMD3<Double>(1, 0, 0) : up
                    projected = simd_cross(tangent, reference)
                }
                normal = safeNormalize(projected)
            } else {
                let reference = abs(tangent.y) > 0.92 ? SIMD3<Double>(1, 0, 0) : up
                normal = safeNormalize(simd_cross(tangent, reference))
            }
            let binormal = safeNormalize(simd_cross(tangent, normal))
            previousNormal = normal

            for side in 0..<sides {
                let angle = 2 * Double.pi * Double(side) / Double(sides)
                let offset = normal * (cos(angle) * radius) + binormal * (sin(angle) * radius)
                vertices.append(scnVector(point + offset))
            }
        }

        let sidesCount = UInt32(sides)
        for segment in 0..<(points.count - 1) {
            let base = UInt32(segment) * sidesCount
            let nextBase = UInt32(segment + 1) * sidesCount
            for side in 0..<sides {
                let next = UInt32((side + 1) % sides)
                let sideOffset = UInt32(side)
                indices.append(base + sideOffset)
                indices.append(nextBase + sideOffset)
                indices.append(base + next)
                indices.append(base + next)
                indices.append(nextBase + sideOffset)
                indices.append(nextBase + next)
            }
        }

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.materials = [material]
        return geometry
    }

    private func safeNormalize(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        let length = simd_length(vector)
        guard length > 0.000_001 else { return SIMD3<Double>(0, 1, 0) }
        return vector / length
    }

    private func scnVector(_ point: SIMD3<Double>) -> SCNVector3 {
        SCNVector3(
            x: CGFloat(point.x),
            y: CGFloat(point.y),
            z: CGFloat(point.z)
        )
    }

    // MARK: - Generated textures

    private static func makeLightingEnvironmentImage() -> NSImage {
        let size = NSSize(width: 512, height: 256)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        if let gradient = NSGradient(
            colorsAndLocations:
                (NSColor(calibratedWhite: 0.30, alpha: 1), 0.0),
                (NSColor(calibratedWhite: 0.78, alpha: 1), 0.47),
                (NSColor(calibratedWhite: 1.0, alpha: 1), 0.58),
                (NSColor(calibratedWhite: 0.62, alpha: 1), 1.0)
        ) {
            gradient.draw(in: NSRect(origin: .zero, size: size), angle: -90)
        }

        NSColor(calibratedWhite: 1.0, alpha: 0.95).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 40, y: 152, width: 140, height: 48),
            xRadius: 20,
            yRadius: 20
        ).fill()
        NSBezierPath(
            roundedRect: NSRect(x: 300, y: 165, width: 110, height: 34),
            xRadius: 16,
            yRadius: 16
        ).fill()
        return image
    }

    private static func makeMistTexture() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let colors = [
            NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.85, alpha: 0.42),
            NSColor(calibratedRed: 0.82, green: 0.88, blue: 0.91, alpha: 0.14),
            NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.96, alpha: 0.0)
        ]
        if let gradient = NSGradient(colors: colors) {
            gradient.draw(
                in: NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 240, height: 240)),
                relativeCenterPosition: .zero
            )
        }
        return image
    }

    private static func makeSoftShadowImage() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let colors = [
            NSColor(calibratedWhite: 0, alpha: 0.34),
            NSColor(calibratedWhite: 0, alpha: 0.10),
            NSColor(calibratedWhite: 0, alpha: 0.0)
        ]
        if let gradient = NSGradient(colors: colors) {
            gradient.draw(
                in: NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 236, height: 236)),
                relativeCenterPosition: .zero
            )
        }
        return image
    }
}
