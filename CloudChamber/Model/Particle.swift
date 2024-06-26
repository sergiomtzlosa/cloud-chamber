import AppKit
import Foundation
import simd

/// The available radiation-source presets.
enum ParticleSource: String, Codable, CaseIterable {
    case mixed
    case alpha
    case beta
    case muon
    case gamma
    case cosmic

    var title: String {
        switch self {
        case .mixed: return "Mixed particles"
        case .alpha: return "Alpha particles"
        case .beta: return "Beta particles"
        case .muon: return "Muons"
        case .gamma: return "Gamma conversions"
        case .cosmic: return "Cosmic showers"
        }
    }

    var usesSourceMarker: Bool {
        switch self {
        case .mixed, .alpha, .beta:
            return true
        case .muon, .gamma, .cosmic:
            return false
        }
    }
}

/// A particle with a visible track. Neutral gammas are represented by their conversion pair.
enum ParticleKind: String, Codable, CaseIterable {
    case alpha
    case betaMinus
    case betaPlus
    case muon
    case proton
    case deltaElectron

    var title: String {
        switch self {
        case .alpha: return "Alpha"
        case .betaMinus: return "Electron"
        case .betaPlus: return "Positron"
        case .muon: return "Muon"
        case .proton: return "Proton"
        case .deltaElectron: return "Delta ray"
        }
    }

    var symbol: String {
        switch self {
        case .alpha: return "α"
        case .betaMinus: return "β⁻"
        case .betaPlus: return "β⁺"
        case .muon: return "μ"
        case .proton: return "p"
        case .deltaElectron: return "δ"
        }
    }

    var legendTitle: String {
        switch self {
        case .alpha: return "α alpha"
        case .betaMinus: return "β⁻ electron"
        case .betaPlus: return "β⁺ positron"
        case .muon: return "μ muon"
        case .proton: return "p proton"
        case .deltaElectron: return "δ delta ray"
        }
    }

    var charge: Int {
        switch self {
        case .alpha: return 2
        case .betaMinus, .deltaElectron: return -1
        case .betaPlus, .muon, .proton: return 1
        }
    }

    /// Momentum in arbitrary simulation units. Larger values bend less in a magnetic field.
    var nominalMomentum: Double {
        switch self {
        case .alpha: return 55
        case .betaMinus, .betaPlus: return 2.4
        case .muon: return 180
        case .proton: return 16
        case .deltaElectron: return 1.8
        }
    }

    /// Approximate path length in chamber world units at an energy scale of 1.
    var nominalRange: Double {
        switch self {
        case .alpha: return 0.42
        case .betaMinus, .betaPlus: return 0.95
        case .muon: return 4.0
        case .proton: return 0.66
        case .deltaElectron: return 0.11
        }
    }

    /// Animation speed in chamber world units per simulated second.
    var speed: Double {
        switch self {
        case .alpha: return 0.40
        case .betaMinus, .betaPlus: return 0.72
        case .muon: return 1.22
        case .proton: return 0.56
        case .deltaElectron: return 0.88
        }
    }

    /// Angular spread per sqrt(normalized distance) from multiple scattering.
    var scattering: Double {
        switch self {
        case .alpha: return 0.030
        case .betaMinus, .betaPlus: return 0.55
        case .muon: return 0.018
        case .proton: return 0.14
        case .deltaElectron: return 0.65
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .alpha: return 3.2
        case .betaMinus, .betaPlus: return 1.35
        case .muon: return 1.05
        case .proton: return 1.9
        case .deltaElectron: return 1.0
        }
    }

    var baseOpacity: CGFloat {
        switch self {
        case .alpha: return 0.96
        case .betaMinus, .betaPlus: return 0.88
        case .muon: return 0.58
        case .proton: return 0.82
        case .deltaElectron: return 0.68
        }
    }

    var color: NSColor {
        switch self {
        case .alpha:
            return NSColor(calibratedRed: 0.72, green: 0.18, blue: 0.16, alpha: 1)
        case .betaMinus:
            return NSColor(calibratedRed: 0.09, green: 0.38, blue: 0.75, alpha: 1)
        case .betaPlus:
            return NSColor(calibratedRed: 0.00, green: 0.51, blue: 0.57, alpha: 1)
        case .muon:
            return NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.69, alpha: 1)
        case .proton:
            return NSColor(calibratedRed: 0.76, green: 0.40, blue: 0.03, alpha: 1)
        case .deltaElectron:
            return NSColor(calibratedRed: 0.43, green: 0.49, blue: 0.56, alpha: 1)
        }
    }

    var canProduceDeltaRays: Bool {
        switch self {
        case .alpha, .muon, .proton: return true
        case .betaMinus, .betaPlus, .deltaElectron: return false
        }
    }

    var deltaRayProbabilityPerSecond: Double {
        switch self {
        case .alpha: return 0.06
        case .muon: return 0.24
        case .proton: return 0.18
        case .betaMinus, .betaPlus, .deltaElectron: return 0
        }
    }
}

/// A rendered trail. Points are in the chamber's local 3D coordinate space:
/// x/z are horizontal, y is vertical, and the origin is the center of the cold plate.
struct ParticleTrack: Identifiable {
    let id: UUID
    let kind: ParticleKind
    var points: [SIMD3<Double>]
    var isActive: Bool
    var fadeProgress: Double
    var drawsConversionVertex: Bool

    init(
        id: UUID = UUID(),
        kind: ParticleKind,
        points: [SIMD3<Double>],
        isActive: Bool = true,
        fadeProgress: Double = 0,
        drawsConversionVertex: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.points = points
        self.isActive = isActive
        self.fadeProgress = fadeProgress
        self.drawsConversionVertex = drawsConversionVertex
    }
}

struct SimulationStatistics: Equatable {
    var totalEvents: Int = 0
    var totalTracks: Int = 0
    var visibleTracks: Int = 0
    var activeParticles: Int = 0
    var countsByKind: [ParticleKind: Int] = [:]

    func count(for kind: ParticleKind) -> Int {
        countsByKind[kind, default: 0]
    }
}
