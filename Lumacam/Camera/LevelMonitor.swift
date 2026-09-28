import CoreMotion
import Observation

/// Tracks how far the phone is rotated away from level, using gravity from Core Motion.
@Observable @MainActor
final class LevelMonitor {
    /// Rotation of the phone around the axis through the screen, in radians. 0 is upright portrait.
    private(set) var roll: Double = 0
    /// Distance from the nearest level orientation (portrait or either landscape), in radians.
    private(set) var deviation: Double = 0
    /// False when the phone is lying close to flat, where roll isn't meaningful.
    private(set) var isUpright = false

    @ObservationIgnored private let motion = CMMotionManager()

    var isLevel: Bool { abs(deviation) < Self.levelTolerance }
    var nearestLevelAngle: Double { roll - deviation }

    static let levelTolerance = 1.0 * .pi / 180

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let gravity = data?.gravity else { return }
            self?.update(x: gravity.x, y: gravity.y, z: gravity.z)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    private func update(x: Double, y: Double, z: Double) {
        let reading = Self.reading(x: x, y: y, z: z)
        roll = reading.roll
        deviation = reading.deviation
        isUpright = reading.isUpright
    }

    nonisolated static func reading(x: Double, y: Double, z: Double) -> (roll: Double, deviation: Double, isUpright: Bool) {
        let roll = atan2(x, -y)
        let quarterTurn = Double.pi / 2
        let nearest = (roll / quarterTurn).rounded() * quarterTurn
        return (roll, roll - nearest, abs(z) < 0.85)
    }
}
