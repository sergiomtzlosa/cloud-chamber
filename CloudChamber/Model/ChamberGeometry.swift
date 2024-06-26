import Foundation
import simd

enum ChamberGeometry {
    static let innerRadius: Double = 1.0
    static let floorY: Double = -0.55
    static let ceilingY: Double = 0.58
    static let entryY: Double = 0.63
    static let sourcePosition = SIMD3<Double>(0, -0.49, 0)

    static func isInside(_ point: SIMD3<Double>, inset: Double = 0) -> Bool {
        let radial = sqrt(point.x * point.x + point.z * point.z)
        return radial <= max(0, innerRadius - inset)
            && point.y >= floorY + inset
            && point.y <= ceilingY - inset
    }
}
