import Foundation
import Vision

struct HandLandmarks {
    let wrist: CGPoint
    let thumbTip: CGPoint
    let thumbIP: CGPoint
    let thumbMP: CGPoint
    let thumbCMC: CGPoint
    let indexTip: CGPoint
    let indexDIP: CGPoint
    let indexPIP: CGPoint
    let indexMCP: CGPoint
    let middleTip: CGPoint
    let middleDIP: CGPoint
    let middlePIP: CGPoint
    let middleMCP: CGPoint
    let ringTip: CGPoint
    let ringDIP: CGPoint
    let ringPIP: CGPoint
    let ringMCP: CGPoint
    let littleTip: CGPoint
    let littleDIP: CGPoint
    let littlePIP: CGPoint
    let littleMCP: CGPoint

    var allPoints: [CGPoint] {
        [wrist, thumbTip, thumbIP, thumbMP, thumbCMC,
         indexTip, indexDIP, indexPIP, indexMCP,
         middleTip, middleDIP, middlePIP, middleMCP,
         ringTip, ringDIP, ringPIP, ringMCP,
         littleTip, littleDIP, littlePIP, littleMCP]
    }

    static let boneConnections: [(Int, Int)] = [
        (0, 4), (4, 3), (3, 2), (2, 1),       // Thumb: wrist→CMC→MP→IP→tip
        (0, 8), (8, 7), (7, 6), (6, 5),       // Index: wrist→MCP→PIP→DIP→tip
        (0, 12), (12, 11), (11, 10), (10, 9),  // Middle
        (0, 16), (16, 15), (15, 14), (14, 13), // Ring
        (0, 20), (20, 19), (19, 18), (18, 17), // Little
    ]

    init?(from observation: VNHumanHandPoseObservation) {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func pt(_ name: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let p = points[name], p.confidence > 0.3 else { return nil } // min confidence
            return CGPoint(x: p.location.x, y: p.location.y)
        }

        guard let w = pt(.wrist) else { return nil }

        wrist = w
        thumbTip = pt(.thumbTip) ?? w
        thumbIP = pt(.thumbIP) ?? w
        thumbMP = pt(.thumbMP) ?? w
        thumbCMC = pt(.thumbCMC) ?? w
        indexTip = pt(.indexTip) ?? w
        indexDIP = pt(.indexDIP) ?? w
        indexPIP = pt(.indexPIP) ?? w
        indexMCP = pt(.indexMCP) ?? w
        middleTip = pt(.middleTip) ?? w
        middleDIP = pt(.middleDIP) ?? w
        middlePIP = pt(.middlePIP) ?? w
        middleMCP = pt(.middleMCP) ?? w
        ringTip = pt(.ringTip) ?? w
        ringDIP = pt(.ringDIP) ?? w
        ringPIP = pt(.ringPIP) ?? w
        ringMCP = pt(.ringMCP) ?? w
        littleTip = pt(.littleTip) ?? w
        littleDIP = pt(.littleDIP) ?? w
        littlePIP = pt(.littlePIP) ?? w
        littleMCP = pt(.littleMCP) ?? w
    }
}
