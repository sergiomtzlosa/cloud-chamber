import Foundation
import simd

struct LiveParticle {
    let trackID: UUID
    let kind: ParticleKind
    var position: SIMD3<Double>
    var direction: SIMD3<Double>
    let speed: Double
    let momentum: Double
    var remainingRange: Double
    let charge: Int
}

final class SimulationEngine {
    var configuration: ChamberConfiguration
    private(set) var tracks: [ParticleTrack] = []
    private(set) var statistics = SimulationStatistics()
    private(set) var simulationTime: TimeInterval = 0
    private(set) var seed: UInt64

    private var liveParticles: [LiveParticle] = []
    private var random: SeededRandom
    private var eventAccumulator: Double = 0
    private var hasPrimed = false
    private var totalEventCount = 0
    private var totalTrackCount = 0

    private let maxLiveParticles = 120
    private let maxTracks = 400

    init(configuration: ChamberConfiguration = .default, seed: UInt64 = 0xC10D) {
        self.configuration = configuration.clamped()
        self.seed = seed
        random = SeededRandom(seed: seed)
        refreshStatistics()
    }

    // MARK: - Lifecycle

    func update(dt rawDelta: TimeInterval) {
        guard rawDelta > 0 else { return }
        let dt = min(max(rawDelta, 0), 0.05) * max(configuration.timeScale, 0.25)

        if !hasPrimed, configuration.eventsPerSecond > 0 {
            hasPrimed = true
            emitEvent()
        }

        eventAccumulator += configuration.eventsPerSecond * dt
        var generatedThisFrame = 0
        while eventAccumulator >= 1, generatedThisFrame < 24 {
            eventAccumulator -= 1
            emitEvent()
            generatedThisFrame += 1
        }

        advanceParticles(dt: dt)
        ageTracks(dt: dt)
        pruneTracks()
        simulationTime += dt
        refreshStatistics()
    }

    func clearTracks() {
        tracks.removeAll(keepingCapacity: true)
        liveParticles.removeAll(keepingCapacity: true)
        eventAccumulator = 0
        totalEventCount = 0
        totalTrackCount = 0
        refreshStatistics()
    }

    func reset(seed: UInt64? = nil) {
        if let seed {
            self.seed = seed
            random = SeededRandom(seed: seed)
        }
        tracks.removeAll(keepingCapacity: true)
        liveParticles.removeAll(keepingCapacity: true)
        eventAccumulator = 0
        hasPrimed = false
        simulationTime = 0
        totalEventCount = 0
        totalTrackCount = 0
        refreshStatistics()
    }

    // MARK: - Event generation

    private func emitEvent() {
        totalEventCount += 1

        switch configuration.source {
        case .alpha:
            emitSourceParticle(.alpha)
        case .beta:
            emitSourceParticle(random.chance(0.85) ? .betaMinus : .betaPlus)
        case .muon:
            emitMuon()
        case .gamma:
            emitGammaConversion()
        case .cosmic:
            emitCosmicShower()
        case .mixed:
            emitMixedEvent()
        }
    }

    private func emitMixedEvent() {
        let roll = random.unit()
        if roll < 0.26 {
            emitSourceParticle(.alpha)
        } else if roll < 0.56 {
            emitSourceParticle(random.chance(0.85) ? .betaMinus : .betaPlus)
        } else if roll < 0.73 {
            emitMuon()
        } else if roll < 0.81 {
            emitSourceParticle(.proton)
        } else if roll < 0.90 {
            emitGammaConversion()
        } else if configuration.cosmicShowers {
            emitCosmicShower()
        } else {
            emitMuon()
        }
    }

    private func emitSourceParticle(_ kind: ParticleKind) {
        let jitter = SIMD3<Double>(
            random.uniform(-0.012, 0.012),
            0,
            random.uniform(-0.012, 0.012)
        )
        spawnParticle(
            kind: kind,
            position: ChamberGeometry.sourcePosition + jitter,
            direction: randomUpwardDirection()
        )
    }

    private func emitMuon() {
        let origin = randomEntryPoint()
        let direction = simd_normalize(
            SIMD3<Double>(
                random.uniform(-0.32, 0.32),
                -1,
                random.uniform(-0.32, 0.32)
            )
        )
        spawnParticle(kind: .muon, position: origin, direction: direction)
    }

    private func emitGammaConversion() {
        let vertex = randomInteriorPoint(
            radialFraction: 0.72,
            heightRange: -0.34...0.34
        )
        let baseDirection = randomUnitVector()
        var axis = simd_cross(baseDirection, SIMD3<Double>(0, 1, 0))
        if simd_length(axis) < 0.05 {
            axis = simd_cross(baseDirection, SIMD3<Double>(1, 0, 0))
        }
        axis = simd_normalize(axis)

        let halfOpening = random.uniform(0.28, 0.62)
        let firstRotation = simd_quatd(angle: halfOpening, axis: axis)
        let secondRotation = simd_quatd(angle: -halfOpening, axis: axis)
        let firstDirection = simd_normalize(firstRotation.act(baseDirection))
        let secondDirection = simd_normalize(secondRotation.act(baseDirection))

        spawnParticle(
            kind: .betaMinus,
            position: vertex,
            direction: firstDirection,
            drawConversionVertex: true
        )
        spawnParticle(
            kind: .betaPlus,
            position: vertex,
            direction: secondDirection
        )
    }

    private func emitCosmicShower() {
        let count = random.integer(in: 2...5)
        let centerAngle = random.uniform(0, 2 * Double.pi)
        let centerRadius = random.uniform(0.20, 0.62)
        let center = SIMD3<Double>(
            cos(centerAngle) * centerRadius,
            ChamberGeometry.entryY,
            sin(centerAngle) * centerRadius
        )

        for index in 0..<count {
            let kind: ParticleKind
            if index == 0 || random.chance(0.55) {
                kind = .muon
            } else {
                kind = .betaMinus
            }

            let offset = SIMD3<Double>(
                random.uniform(-0.15, 0.15),
                0,
                random.uniform(-0.15, 0.15)
            )
            var origin = center + offset
            let horizontalLength = sqrt(origin.x * origin.x + origin.z * origin.z)
            if horizontalLength > 0.88 {
                origin.x *= 0.88 / horizontalLength
                origin.z *= 0.88 / horizontalLength
            }

            let direction = simd_normalize(
                SIMD3<Double>(
                    random.uniform(-0.20, 0.20),
                    -1,
                    random.uniform(-0.20, 0.20)
                )
            )
            spawnParticle(kind: kind, position: origin, direction: direction)
        }
    }

    private func randomUpwardDirection() -> SIMD3<Double> {
        let y = random.uniform(0.22, 0.99)
        let horizontal = sqrt(max(0, 1 - y * y))
        let angle = random.uniform(0, 2 * Double.pi)
        return simd_normalize(
            SIMD3<Double>(
                horizontal * cos(angle),
                y,
                horizontal * sin(angle)
            )
        )
    }

    private func randomUnitVector() -> SIMD3<Double> {
        let y = random.uniform(-1, 1)
        let horizontal = sqrt(max(0, 1 - y * y))
        let angle = random.uniform(0, 2 * Double.pi)
        return simd_normalize(
            SIMD3<Double>(
                horizontal * cos(angle),
                y,
                horizontal * sin(angle)
            )
        )
    }

    private func randomEntryPoint() -> SIMD3<Double> {
        let radius = sqrt(random.uniform(0, 0.86 * 0.86))
        let angle = random.uniform(0, 2 * Double.pi)
        return SIMD3<Double>(
            cos(angle) * radius,
            ChamberGeometry.entryY,
            sin(angle) * radius
        )
    }

    private func randomInteriorPoint(
        radialFraction: Double,
        heightRange: ClosedRange<Double>
    ) -> SIMD3<Double> {
        let radius = sqrt(random.unit()) * ChamberGeometry.innerRadius * radialFraction
        let angle = random.uniform(0, 2 * Double.pi)
        return SIMD3<Double>(
            cos(angle) * radius,
            random.uniform(heightRange.lowerBound, heightRange.upperBound),
            sin(angle) * radius
        )
    }

    @discardableResult
    private func makeParticle(
        kind: ParticleKind,
        position: SIMD3<Double>,
        direction: SIMD3<Double>,
        charge: Int? = nil,
        drawConversionVertex: Bool = false
    ) -> LiveParticle? {
        guard liveParticles.count < maxLiveParticles else { return nil }

        let energyScale = configuration.energyScale
        let momentum = kind.nominalMomentum * energyScale * random.uniform(0.90, 1.10)
        let range = kind.nominalRange * energyScale * random.uniform(0.75, 1.25)
        let speed = kind.speed * random.uniform(0.90, 1.10)
        let track = ParticleTrack(
            kind: kind,
            points: [position],
            drawsConversionVertex: drawConversionVertex
        )
        tracks.append(track)
        totalTrackCount += 1

        return LiveParticle(
            trackID: track.id,
            kind: kind,
            position: position,
            direction: direction,
            speed: speed,
            momentum: momentum,
            remainingRange: range,
            charge: charge ?? kind.charge
        )
    }

    @discardableResult
    private func spawnParticle(
        kind: ParticleKind,
        position: SIMD3<Double>,
        direction: SIMD3<Double>,
        charge: Int? = nil,
        drawConversionVertex: Bool = false
    ) -> UUID? {
        guard let particle = makeParticle(
            kind: kind,
            position: position,
            direction: direction,
            charge: charge,
            drawConversionVertex: drawConversionVertex
        ) else { return nil }
        liveParticles.append(particle)
        return particle.trackID
    }

    // MARK: - Motion

    private func advanceParticles(dt: Double) {
        guard !liveParticles.isEmpty else { return }

        var trackIndices: [UUID: Int] = [:]
        for (index, track) in tracks.enumerated() {
            trackIndices[track.id] = index
        }

        let existingParticles = liveParticles
        liveParticles.removeAll(keepingCapacity: true)
        var newSecondaryParticles: [LiveParticle] = []

        for var particle in existingParticles {
            let stepDistance = particle.speed * dt
            let magneticDirection = Physics.deflectedDirection(
                particle.direction,
                charge: particle.charge,
                magneticField: configuration.magneticField,
                momentum: particle.momentum,
                dt: dt
            )

            if configuration.multipleScattering {
                let noise = SIMD3<Double>(
                    random.gaussian(),
                    random.gaussian(),
                    random.gaussian()
                )
                particle.direction = Physics.scatteredDirection(
                    magneticDirection,
                    kind: particle.kind,
                    distance: stepDistance,
                    noise: noise
                )
            } else {
                particle.direction = magneticDirection
            }

            particle.position += particle.direction * stepDistance
            particle.remainingRange -= stepDistance

            if let index = trackIndices[particle.trackID] {
                tracks[index].points.append(particle.position)
            }

            if !isWithinMotionBounds(particle.position) || particle.remainingRange <= 0 {
                continue
            }

            liveParticles.append(particle)

            if particle.kind.canProduceDeltaRays,
               random.chance(particle.kind.deltaRayProbabilityPerSecond * dt) {
                let sideways = simd_normalize(
                    particle.direction + randomUnitVector() * 0.9
                )
                if let delta = makeParticle(
                    kind: .deltaElectron,
                    position: particle.position,
                    direction: sideways
                ) {
                    newSecondaryParticles.append(delta)
                }
            }
        }

        liveParticles.append(contentsOf: newSecondaryParticles)
    }

    private func isWithinMotionBounds(_ position: SIMD3<Double>) -> Bool {
        let radialDistance = sqrt(position.x * position.x + position.z * position.z)
        let radialLimit = ChamberGeometry.innerRadius + 0.08
        let lowerLimit = ChamberGeometry.floorY - 0.08
        let upperLimit = ChamberGeometry.ceilingY + 0.09
        return radialDistance <= radialLimit
            && position.y >= lowerLimit
            && position.y <= upperLimit
    }

    private func ageTracks(dt: Double) {
        let activeIDs = Set(liveParticles.map(\.trackID))
        let persistence = max(configuration.trackPersistence, 0.1)
        var kept: [ParticleTrack] = []
        kept.reserveCapacity(tracks.count)

        for var track in tracks {
            if activeIDs.contains(track.id) {
                track.isActive = true
                track.fadeProgress = 0
            } else {
                if track.isActive {
                    track.isActive = false
                    track.fadeProgress = 0
                }
                track.fadeProgress += dt / persistence
                if track.fadeProgress >= 1 {
                    continue
                }
            }
            kept.append(track)
        }

        tracks = kept
    }

    private func pruneTracks() {
        guard tracks.count > maxTracks else { return }
        tracks.removeFirst(tracks.count - maxTracks)
    }

    private func refreshStatistics() {
        var counts: [ParticleKind: Int] = [:]
        for track in tracks {
            counts[track.kind, default: 0] += 1
        }
        statistics = SimulationStatistics(
            totalEvents: totalEventCount,
            totalTracks: totalTrackCount,
            visibleTracks: tracks.count,
            activeParticles: liveParticles.count,
            countsByKind: counts
        )
    }
}
