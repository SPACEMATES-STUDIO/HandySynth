import Foundation
import Vision

struct BodyLandmarks {
    let nose: CGPoint
    let leftEye: CGPoint
    let rightEye: CGPoint
    let leftEar: CGPoint
    let rightEar: CGPoint
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let leftElbow: CGPoint
    let rightElbow: CGPoint
    let leftWrist: CGPoint
    let rightWrist: CGPoint
    let root: CGPoint
    let leftHip: CGPoint
    let rightHip: CGPoint
    let leftKnee: CGPoint
    let rightKnee: CGPoint
    let leftAnkle: CGPoint
    let rightAnkle: CGPoint

    var allPoints: [CGPoint] {
        [nose, leftEye, rightEye, leftEar, rightEar,
         leftShoulder, rightShoulder, leftElbow, rightElbow,
         leftWrist, rightWrist, root, leftHip, rightHip,
         leftKnee, rightKnee, leftAnkle, rightAnkle]
    }

    // Index mapping:
    //  0=nose, 1=leftEye, 2=rightEye, 3=leftEar, 4=rightEar,
    //  5=leftShoulder, 6=rightShoulder, 7=leftElbow, 8=rightElbow,
    //  9=leftWrist, 10=rightWrist, 11=root, 12=leftHip, 13=rightHip,
    //  14=leftKnee, 15=rightKnee, 16=leftAnkle, 17=rightAnkle
    static let boneConnections: [(Int, Int)] = [
        // Head
        (0, 1), (0, 2), (1, 3), (2, 4),
        // Shoulders
        (5, 6),
        // Left arm
        (5, 7), (7, 9),
        // Right arm
        (6, 8), (8, 10),
        // Torso
        (5, 12), (6, 13),
        // Hips
        (12, 13),
        // Left leg
        (12, 14), (14, 16),
        // Right leg
        (13, 15), (15, 17),
    ]

    init?(from observation: VNHumanBodyPoseObservation) {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func pt(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = points[name], p.confidence > 0.1 else { return nil }
            return CGPoint(x: p.location.x, y: p.location.y)
        }

        guard let n = pt(.nose),
              let ls = pt(.leftShoulder),
              let rs = pt(.rightShoulder) else { return nil }

        nose = n
        leftEye = pt(.leftEye) ?? n
        rightEye = pt(.rightEye) ?? n
        leftEar = pt(.leftEar) ?? n
        rightEar = pt(.rightEar) ?? n
        leftShoulder = ls
        rightShoulder = rs
        leftElbow = pt(.leftElbow) ?? ls
        rightElbow = pt(.rightElbow) ?? rs
        leftWrist = pt(.leftWrist) ?? leftElbow
        rightWrist = pt(.rightWrist) ?? rightElbow
        root = pt(.root) ?? CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2 - 0.2)
        leftHip = pt(.leftHip) ?? root
        rightHip = pt(.rightHip) ?? root
        leftKnee = pt(.leftKnee) ?? leftHip
        rightKnee = pt(.rightKnee) ?? rightHip
        leftAnkle = pt(.leftAnkle) ?? leftKnee
        rightAnkle = pt(.rightAnkle) ?? rightKnee
    }
}
