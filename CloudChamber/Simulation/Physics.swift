import Foundation
import simd

enum Physics {
    /// Angular velocity for a charged particle in a uniform magnetic field.
    ///
    /// The units are deliberately scaled for an illustrative simulation: beta tracks visibly
    /// curve, while high-momentum alpha and muon tracks stay almost straight. The magnetic field
    /// points vertically along +Y in chamber space.
    static let curvatureScale = 5.0
    static let magneticFieldAxis = SIMD3<Double>(0, 1, 0)

    static func curvatureRate(charge: Int, magneticField: Double, momentum: Double) -> Double {
        guard charge != 0, magneticField != 0 else { return 0 }
        let safeMomentum = max(momentum, 0.001)
        return curvatureScale * magneticField * Double(charge) / safeMomentum
    }

    static func deflectedDirection(
        _ direction: SIMD3<Double>,
        charge: Int,
        magneticField: Double,
        momentum: Double,
        dt: Double
    ) -> SIMD3<Double> {
        let rate = curvatureRate(
            charge: charge,
            magneticField: magneticField,
            momentum: momentum
        )
        guard abs(rate) > 0, dt != 0 else { return direction }

        let angle = -rate * dt
        let rotation = simd_quatd(angle: angle, axis: magneticFieldAxis)
        return simd_normalize(rotation.act(direction))
    }

    /// Standard deviation of the angular kick for one simulation step.
    static func scatteringSigma(kind: ParticleKind, distance: Double) -> Double {
        let step = max(distance, 0)
        return kind.scattering * sqrt(step)
    }

    static func scatteredDirection(
        _ direction: SIMD3<Double>,
        kind: ParticleKind,
        distance: Double,
        noise: SIMD3<Double>
    ) -> SIMD3<Double> {
        let sigma = scatteringSigma(kind: kind, distance: distance)
        guard sigma > 0 else { return direction }
        return simd_normalize(direction + noise * sigma)
    }
}
