import Foundation

struct ChamberConfiguration: Codable, Equatable {
    var source: ParticleSource
    var eventsPerSecond: Double
    var magneticField: Double
    var supersaturation: Double
    var energyScale: Double
    var timeScale: Double
    var trackPersistence: Double
    var multipleScattering: Bool
    var cosmicShowers: Bool
    var showLegend: Bool
    var showStatistics: Bool
    var showMist: Bool

    init(
        source: ParticleSource = .mixed,
        eventsPerSecond: Double = 2.0,
        magneticField: Double = 0.4,
        supersaturation: Double = 0.78,
        energyScale: Double = 1.0,
        timeScale: Double = 1.0,
        trackPersistence: Double = 3.0,
        multipleScattering: Bool = true,
        cosmicShowers: Bool = true,
        showLegend: Bool = true,
        showStatistics: Bool = true,
        showMist: Bool = true
    ) {
        self.source = source
        self.eventsPerSecond = eventsPerSecond
        self.magneticField = magneticField
        self.supersaturation = supersaturation
        self.energyScale = energyScale
        self.timeScale = timeScale
        self.trackPersistence = trackPersistence
        self.multipleScattering = multipleScattering
        self.cosmicShowers = cosmicShowers
        self.showLegend = showLegend
        self.showStatistics = showStatistics
        self.showMist = showMist
    }

    static let `default` = ChamberConfiguration()

    static let storageKey = "CloudChamber.configuration.v1"

    func clamped() -> ChamberConfiguration {
        var result = self
        result.eventsPerSecond = min(max(result.eventsPerSecond, 0), 10)
        result.magneticField = min(max(result.magneticField, -1.5), 1.5)
        result.supersaturation = min(max(result.supersaturation, 0), 1)
        result.energyScale = min(max(result.energyScale, 0.5), 2)
        result.timeScale = min(max(result.timeScale, 0.25), 2)
        result.trackPersistence = min(max(result.trackPersistence, 0.5), 10)
        return result
    }

    static func load(from defaults: UserDefaults = .standard) -> ChamberConfiguration {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(ChamberConfiguration.self, from: data)
        else {
            return .default
        }
        return decoded.clamped()
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func clearSaved(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
