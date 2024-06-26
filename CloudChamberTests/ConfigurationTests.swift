import XCTest
@testable import CloudChamber

final class ConfigurationTests: XCTestCase {
    func testDefaultConfigurationIsWithinBounds() {
        let config = ChamberConfiguration.default
        XCTAssertEqual(config.source, .mixed)
        XCTAssertTrue((0...10).contains(config.eventsPerSecond))
        XCTAssertTrue((-1.5...1.5).contains(config.magneticField))
        XCTAssertTrue((0...1).contains(config.supersaturation))
        XCTAssertTrue((0.5...2).contains(config.energyScale))
        XCTAssertTrue((0.25...2).contains(config.timeScale))
        XCTAssertTrue((0.5...10).contains(config.trackPersistence))
    }

    func testClampingEnforcesSupportedRanges() {
        var config = ChamberConfiguration.default
        config.eventsPerSecond = -4
        config.magneticField = 9
        config.supersaturation = 4
        config.energyScale = 0.1
        config.timeScale = 8
        config.trackPersistence = 0.01

        let clamped = config.clamped()
        XCTAssertEqual(clamped.eventsPerSecond, 0)
        XCTAssertEqual(clamped.magneticField, 1.5)
        XCTAssertEqual(clamped.supersaturation, 1)
        XCTAssertEqual(clamped.energyScale, 0.5)
        XCTAssertEqual(clamped.timeScale, 2)
        XCTAssertEqual(clamped.trackPersistence, 0.5)
    }

    func testConfigurationRoundTripsThroughUserDefaults() throws {
        let suiteName = "CloudChamber.ConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var config = ChamberConfiguration.default
        config.source = .gamma
        config.eventsPerSecond = 6.5
        config.magneticField = -1.2
        config.supersaturation = 0.42
        config.energyScale = 1.75
        config.timeScale = 0.5
        config.trackPersistence = 7.5
        config.multipleScattering = false
        config.cosmicShowers = false
        config.showLegend = false
        config.showStatistics = true
        config.showMist = false

        config.save(to: defaults)
        XCTAssertEqual(ChamberConfiguration.load(from: defaults), config)
    }

    func testConfigurationRoundTripsThroughJSON() throws {
        var config = ChamberConfiguration.default
        config.source = .cosmic
        config.eventsPerSecond = 4.25
        config.magneticField = 0.9
        config.supersaturation = 0.61
        config.energyScale = 1.4
        config.timeScale = 1.75
        config.trackPersistence = 5.5
        config.multipleScattering = false
        config.cosmicShowers = true
        config.showLegend = false
        config.showStatistics = false
        config.showMist = true

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(ChamberConfiguration.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func testCorruptStoredConfigurationFallsBackToDefaults() throws {
        let suiteName = "CloudChamber.ConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not-json".utf8), forKey: ChamberConfiguration.storageKey)
        XCTAssertEqual(ChamberConfiguration.load(from: defaults), .default)
    }
}
