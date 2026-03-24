import Foundation

private enum Thresholds {
    static let pinchDistance: CGFloat = 0.05
    static let thumbExtensionRatio: CGFloat = 1.2
    static let confidenceMinimum: Float = 0.3
    static let spreadClosedBaseline: Float = 0.02
    static let spreadRange: Float = 0.13
}

enum DiscreteGesture: Equatable {
    case none
    case fist
    case pinch
    case point
    case peace
    case openHand(fingerCount: Int)
}

struct FingerState {
    var thumbExtended: Bool = false
    var indexExtended: Bool = false
    var middleExtended: Bool = false
    var ringExtended: Bool = false
    var littleExtended: Bool = false

    var extendedCount: Int {
        [thumbExtended, indexExtended, middleExtended, ringExtended, littleExtended]
            .filter { $0 }.count
    }

    static func from(_ hand: HandLandmarks) -> FingerState {
        FingerState(
            thumbExtended: isThumbExtended(hand),
            indexExtended: hand.indexTip.y > hand.indexPIP.y,
            middleExtended: hand.middleTip.y > hand.middlePIP.y,
            ringExtended: hand.ringTip.y > hand.ringPIP.y,
            littleExtended: hand.littleTip.y > hand.littlePIP.y
        )
    }

    private static func isThumbExtended(_ hand: HandLandmarks) -> Bool {
        let tipDist = hypot(hand.thumbTip.x - hand.indexMCP.x,
                            hand.thumbTip.y - hand.indexMCP.y)
        let ipDist = hypot(hand.thumbIP.x - hand.indexMCP.x,
                           hand.thumbIP.y - hand.indexMCP.y)
        return tipDist > ipDist * Thresholds.thumbExtensionRatio
    }
}

struct GestureDetector {
    static func detectGesture(hand: HandLandmarks) -> DiscreteGesture {
        let fingers = FingerState.from(hand)
        let pinchDist = hypot(hand.thumbTip.x - hand.indexTip.x,
                              hand.thumbTip.y - hand.indexTip.y)

        // Pinch: thumb and index tips very close
        if pinchDist < Thresholds.pinchDistance {
            return .pinch
        }

        // Fist: no fingers extended
        if fingers.extendedCount == 0 {
            return .fist
        }

        // Point: only index extended
        if fingers.indexExtended && !fingers.middleExtended &&
           !fingers.ringExtended && !fingers.littleExtended {
            return .point
        }

        // Peace: index + middle extended, others curled
        if fingers.indexExtended && fingers.middleExtended &&
           !fingers.ringExtended && !fingers.littleExtended {
            return .peace
        }

        return .openHand(fingerCount: fingers.extendedCount)
    }

    static func fingerSpread(hand: HandLandmarks) -> Float {
        let d1 = hypot(hand.indexTip.x - hand.middleTip.x,
                        hand.indexTip.y - hand.middleTip.y)
        let d2 = hypot(hand.middleTip.x - hand.ringTip.x,
                        hand.middleTip.y - hand.ringTip.y)
        let d3 = hypot(hand.ringTip.x - hand.littleTip.x,
                        hand.ringTip.y - hand.littleTip.y)
        let avgSpread = Float((d1 + d2 + d3) / 3.0)
        // Normalize: ~0.02 = closed, ~0.15 = wide spread
        return min(max((avgSpread - Thresholds.spreadClosedBaseline) / Thresholds.spreadRange, 0.0), 1.0)
    }
}

// MARK: - Debouncing

class GestureDebouncer {
    private var history: [DiscreteGesture] = []
    let requiredFrames: Int

    init(requiredFrames: Int = 5) {
        self.requiredFrames = requiredFrames
    }

    func update(_ gesture: DiscreteGesture) -> DiscreteGesture {
        history.append(gesture)
        if history.count > requiredFrames {
            history.removeFirst(history.count - requiredFrames)
        }

        guard history.count >= requiredFrames else { return history.first ?? .none }

        let allSame = history.allSatisfy { $0 == history.last }
        return allSame ? (history.last ?? .none) : (history.first ?? .none)
    }

    func reset() {
        history.removeAll()
    }
}
