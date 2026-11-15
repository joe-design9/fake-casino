import CoreGraphics
import Foundation

/// Time-based reel curve. Position is in symbol cells, positive in the spin direction.
/// The value at `duration` is exactly `travel`, so the strip can land on a known cell.
struct ReelMotion: Equatable {
    var windup: Double
    var accel: Double
    var cruise: Double
    var decel: Double
    var settle: Double
    var nudge: CGFloat
    var overshoot: CGFloat
    var speed: CGFloat
    var travel: CGFloat

    var duration: Double { windup + accel + cruise + decel + settle }

    var accelDistance: CGFloat { speed * CGFloat(accel) / 2 }
    var decelDistance: CGFloat { speed * CGFloat(decel) / 2 }

    static func make(reel: Int, turbo: Bool, anticipate: Bool, uiTest: Bool) -> ReelMotion {
        if uiTest {
            return assemble(
                windup: 0.03,
                accel: 0.06,
                cruiseBase: 0.06 + Double(reel) * 0.035,
                decel: 0.08,
                settle: 0.04,
                nudge: 0.08,
                overshoot: 0.05,
                speed: 36,
                extraCruise: anticipate ? 0.06 : 0
            )
        }
        return assemble(
            windup: turbo ? 0.07 : 0.12,
            accel: turbo ? 0.16 : 0.26,
            cruiseBase: (turbo ? 0.16 : 0.32) + Double(reel) * (turbo ? 0.12 : 0.20),
            decel: turbo ? 0.22 : 0.42,
            settle: turbo ? 0.10 : 0.18,
            nudge: turbo ? 0.14 : 0.28,
            overshoot: turbo ? 0.08 : 0.16,
            speed: turbo ? 32 : 22,
            extraCruise: anticipate ? (turbo ? 0.42 : 0.85) : 0
        )
    }

    /// Builds a curve whose cruise length absorbs stagger and anticipation,
    /// and whose end position is a whole number of cells.
    private static func assemble(
        windup: Double,
        accel: Double,
        cruiseBase: Double,
        decel: Double,
        settle: Double,
        nudge: CGFloat,
        overshoot: CGFloat,
        speed: CGFloat,
        extraCruise: Double
    ) -> ReelMotion {
        let accelDistance = speed * CGFloat(accel) / 2
        let decelDistance = speed * CGFloat(decel) / 2
        let minimumCruise = CGFloat(max(0.05, cruiseBase + extraCruise)) * speed
        let rawEnd = -nudge + accelDistance + minimumCruise + decelDistance
        let travel = (rawEnd - overshoot).rounded(.up)
        let cruiseDistance = max(speed * 0.05, travel + overshoot + nudge - accelDistance - decelDistance)
        let cruise = Double(cruiseDistance / speed)
        return ReelMotion(
            windup: windup,
            accel: accel,
            cruise: cruise,
            decel: decel,
            settle: settle,
            nudge: nudge,
            overshoot: overshoot,
            speed: speed,
            travel: travel
        )
    }

    func sample(_ time: Double) -> (pos: CGFloat, speed: CGFloat) {
        if time <= 0 { return (0, 0) }
        if time >= duration { return (travel, 0) }
        let t1 = windup
        let t2 = t1 + accel
        let t3 = t2 + cruise
        let t4 = t3 + decel
        if time < t1 {
            let u = time / windup
            let shaped = smooth(u)
            return (-nudge * CGFloat(shaped), -nudge * CGFloat(smoothSpeed(u) / windup))
        }
        if time < t2 {
            let u = (time - t1) / accel
            let pos = -nudge + accelDistance * CGFloat(u * u)
            let velocity = accelDistance * CGFloat(2 * u / accel)
            return (pos, velocity)
        }
        if time < t3 {
            let elapsed = time - t2
            let pos = -nudge + accelDistance + speed * CGFloat(elapsed)
            return (pos, speed)
        }
        if time < t4 {
            let u = (time - t3) / decel
            let shaped = 1 - (1 - u) * (1 - u)
            let start = -nudge + accelDistance + speed * CGFloat(cruise)
            let pos = start + decelDistance * CGFloat(shaped)
            let velocity = decelDistance * CGFloat(2 * (1 - u) / decel)
            return (pos, velocity)
        }
        let u = (time - t4) / settle
        let shaped = smooth(u)
        let from = travel + overshoot
        let pos = from + (travel - from) * CGFloat(shaped)
        let velocity = (travel - from) * CGFloat(smoothSpeed(u) / settle)
        return (pos, velocity)
    }

    func quickStop(from position: CGFloat, turbo: Bool) -> ReelQuickStop {
        ReelQuickStop(
            from: position,
            travel: travel,
            overshoot: min(overshoot, 0.1),
            decel: turbo ? 0.20 : 0.32,
            settle: turbo ? 0.08 : 0.12
        )
    }
}

struct ReelQuickStop: Equatable {
    var from: CGFloat
    var travel: CGFloat
    var overshoot: CGFloat
    var decel: Double
    var settle: Double

    var duration: Double { decel + settle }

    func sample(_ time: Double) -> (pos: CGFloat, speed: CGFloat) {
        if time <= 0 { return (from, 0) }
        if time >= duration { return (travel, 0) }
        if time < decel {
            let u = time / decel
            let shaped = 1 - (1 - u) * (1 - u)
            let dest = travel + overshoot
            let pos = from + (dest - from) * CGFloat(shaped)
            let velocity = (dest - from) * CGFloat(2 * (1 - u) / decel)
            return (pos, velocity)
        }
        let u = (time - decel) / max(settle, 0.0001)
        let shaped = smooth(u)
        let fromPos = travel + overshoot
        let pos = fromPos + (travel - fromPos) * CGFloat(shaped)
        let velocity = (travel - fromPos) * CGFloat(smoothSpeed(u) / max(settle, 0.0001))
        return (pos, velocity)
    }
}

private func smooth(_ u: Double) -> Double {
    let x = min(1, max(0, u))
    return x * x * (3 - 2 * x)
}

private func smoothSpeed(_ u: Double) -> Double {
    let x = min(1, max(0, u))
    return 6 * x * (1 - x)
}
