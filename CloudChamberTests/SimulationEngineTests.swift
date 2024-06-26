import XCTest
@testable import CloudChamber

final class SimulationEngineTests: XCTestCase {
    private func makeConfiguration(
        source: ParticleSource,
        rate: Double = 1,
        field: Double = 0,
        persistence: Double = 3
    ) -> ChamberConfiguration {
        ChamberConfiguration(
            source: source,
            eventsPerSecond: rate,
            magneticField: field,
            trackPersistence: persistence
        )
    }

    private func advance(_ engine: SimulationEngine, seconds: Double, step: Double = 1.0 / 60.0) {
        let iterations = max(1, Int((seconds / step).rounded()))
        for _ in 0..<iterations {
            engine.update(dt: step)
        }
    }

    func testNoEventsWhenEmissionRateIsOff() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .alpha, rate: 0),
            seed: 42
        )
        advance(engine, seconds: 0.5)
        XCTAssertTrue(engine.tracks.isEmpty)
        XCTAssertEqual(engine.statistics.totalEvents, 0)
    }

    func testAlphaSourceSpawnsAlphaTracksImmediately() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .alpha),
            seed: 42
        )
        engine.update(dt: 1.0 / 60.0)

        XCTAssertGreaterThanOrEqual(engine.statistics.totalEvents, 1)
        XCTAssertFalse(engine.tracks.isEmpty)
        XCTAssertTrue(engine.tracks.allSatisfy { $0.kind == .alpha })
        XCTAssertGreaterThan(engine.statistics.activeParticles, 0)
    }

    func testBetaSourceProducesChargedBetaTracks() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .beta),
            seed: 7
        )
        engine.update(dt: 1.0 / 60.0)

        XCTAssertFalse(engine.tracks.isEmpty)
        XCTAssertTrue(
            engine.tracks.allSatisfy { $0.kind == .betaMinus || $0.kind == .betaPlus }
        )
    }

    func testGammaConversionProducesPairFromSharedVertex() throws {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .gamma),
            seed: 123
        )
        engine.update(dt: 1.0 / 60.0)

        XCTAssertEqual(engine.tracks.count, 2)
        XCTAssertEqual(
            Set(engine.tracks.map(\.kind)),
            Set([ParticleKind.betaMinus, .betaPlus])
        )

        let electron = try XCTUnwrap(engine.tracks.first { $0.kind == .betaMinus })
        let positron = try XCTUnwrap(engine.tracks.first { $0.kind == .betaPlus })
        let electronStart = try XCTUnwrap(electron.points.first)
        let positronStart = try XCTUnwrap(positron.points.first)

        XCTAssertEqual(electronStart.x, positronStart.x, accuracy: 1e-12)
        XCTAssertEqual(electronStart.y, positronStart.y, accuracy: 1e-12)
        XCTAssertEqual(electronStart.z, positronStart.z, accuracy: 1e-12)
        XCTAssertTrue(electron.drawsConversionVertex)
        XCTAssertFalse(positron.drawsConversionVertex)
    }

    func testCosmicShowerProducesMultipleTracks() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .cosmic),
            seed: 99
        )
        engine.update(dt: 1.0 / 60.0)

        XCTAssertGreaterThanOrEqual(engine.tracks.count, 2)
        XCTAssertTrue(engine.tracks.contains { $0.kind == .muon })
    }

    func testFixedSeedIsDeterministic() {
        let config = ChamberConfiguration(
            source: .mixed,
            eventsPerSecond: 4,
            magneticField: 0.7,
            energyScale: 1.2,
            trackPersistence: 4
        )
        let first = SimulationEngine(configuration: config, seed: 0xDEADBEEF)
        let second = SimulationEngine(configuration: config, seed: 0xDEADBEEF)

        advance(first, seconds: 2)
        advance(second, seconds: 2)

        XCTAssertEqual(first.statistics, second.statistics)
        XCTAssertEqual(first.tracks.count, second.tracks.count)

        for (firstTrack, secondTrack) in zip(first.tracks, second.tracks) {
            XCTAssertEqual(firstTrack.kind, secondTrack.kind)
            XCTAssertEqual(firstTrack.points.count, secondTrack.points.count)
            XCTAssertEqual(firstTrack.fadeProgress, secondTrack.fadeProgress, accuracy: 1e-12)
            for (firstPoint, secondPoint) in zip(firstTrack.points, secondTrack.points) {
                XCTAssertEqual(firstPoint.x, secondPoint.x, accuracy: 1e-12)
                XCTAssertEqual(firstPoint.y, secondPoint.y, accuracy: 1e-12)
                XCTAssertEqual(firstPoint.z, secondPoint.z, accuracy: 1e-12)
            }
        }
    }

    func testTracksFadeAwayAfterPersistence() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .alpha, rate: 1, persistence: 0.5),
            seed: 8
        )
        engine.update(dt: 1.0 / 60.0)
        XCTAssertFalse(engine.tracks.isEmpty)

        engine.configuration.eventsPerSecond = 0
        advance(engine, seconds: 4)
        XCTAssertTrue(engine.tracks.isEmpty)
    }

    func testClearTracksResetsVisibleAndCumulativeCounts() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .alpha),
            seed: 5
        )
        engine.update(dt: 1.0 / 60.0)
        XCTAssertGreaterThan(engine.statistics.totalTracks, 0)

        engine.clearTracks()
        XCTAssertTrue(engine.tracks.isEmpty)
        XCTAssertEqual(engine.statistics.visibleTracks, 0)
        XCTAssertEqual(engine.statistics.totalTracks, 0)
        XCTAssertEqual(engine.statistics.totalEvents, 0)
    }

    func testTrackPointsRemainNearChamberBounds() {
        let engine = SimulationEngine(
            configuration: makeConfiguration(source: .mixed, rate: 8, field: 0.9),
            seed: 77
        )
        advance(engine, seconds: 3)

        for track in engine.tracks {
            for point in track.points {
                let radialDistance = sqrt(point.x * point.x + point.z * point.z)
                XCTAssertLessThanOrEqual(
                    radialDistance,
                    ChamberGeometry.innerRadius + 0.15
                )
                XCTAssertGreaterThanOrEqual(
                    point.y,
                    ChamberGeometry.floorY - 0.15
                )
                XCTAssertLessThanOrEqual(
                    point.y,
                    ChamberGeometry.ceilingY + 0.15
                )
            }
        }
    }
}
