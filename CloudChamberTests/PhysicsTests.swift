import XCTest
import simd
@testable import CloudChamber

final class PhysicsTests: XCTestCase {
    func testZeroMagneticFieldProducesNoCurvature() {
        XCTAssertEqual(Physics.curvatureRate(charge: 1, magneticField: 0, momentum: 2), 0)
    }

    func testOppositeChargesCurveInOppositeDirections() {
        let electron = Physics.curvatureRate(charge: -1, magneticField: 0.8, momentum: 2)
        let positron = Physics.curvatureRate(charge: 1, magneticField: 0.8, momentum: 2)
        XCTAssertLessThan(electron, 0)
        XCTAssertGreaterThan(positron, 0)
        XCTAssertEqual(electron, -positron, accuracy: 1e-12)
    }

    func testBetaCurvesMoreThanAlpha() {
        let beta = abs(
            Physics.curvatureRate(
                charge: ParticleKind.betaMinus.charge,
                magneticField: 0.7,
                momentum: ParticleKind.betaMinus.nominalMomentum
            )
        )
        let alpha = abs(
            Physics.curvatureRate(
                charge: ParticleKind.alpha.charge,
                magneticField: 0.7,
                momentum: ParticleKind.alpha.nominalMomentum
            )
        )
        XCTAssertGreaterThan(beta, alpha * 10)
    }

    func testAlphaScatteringIsMuchSmallerThanBetaScattering() {
        let alpha = Physics.scatteringSigma(kind: .alpha, distance: 0.01)
        let beta = Physics.scatteringSigma(kind: .betaMinus, distance: 0.01)
        XCTAssertGreaterThan(beta, alpha * 10)
    }

    func testScatteringScalesWithSquareRootOfDistance() {
        let shortStep = Physics.scatteringSigma(kind: .betaMinus, distance: 0.01)
        let longStep = Physics.scatteringSigma(kind: .betaMinus, distance: 0.04)
        XCTAssertEqual(longStep, shortStep * 2, accuracy: 1e-12)
    }

    func testThreeDimensionalDeflectionPreservesDirectionLength() {
        let direction = simd_normalize(SIMD3<Double>(1, 0.2, 0.3))
        let deflected = Physics.deflectedDirection(
            direction,
            charge: ParticleKind.betaMinus.charge,
            magneticField: 1.0,
            momentum: ParticleKind.betaMinus.nominalMomentum,
            dt: 1.0 / 60.0
        )
        XCTAssertEqual(simd_length(deflected), 1, accuracy: 1e-12)
    }

    func testOppositeChargesDeflectToOppositeSides() {
        let direction = SIMD3<Double>(1, 0, 0)
        let electron = Physics.deflectedDirection(
            direction,
            charge: -1,
            magneticField: 1.0,
            momentum: 2.0,
            dt: 0.1
        )
        let positron = Physics.deflectedDirection(
            direction,
            charge: 1,
            magneticField: 1.0,
            momentum: 2.0,
            dt: 0.1
        )

        XCTAssertLessThan(electron.z, 0)
        XCTAssertGreaterThan(positron.z, 0)
        XCTAssertEqual(electron.z, -positron.z, accuracy: 1e-12)
    }
}
