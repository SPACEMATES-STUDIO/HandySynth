import Vision
import Combine

class HandTrackingManager: ObservableObject {
    // Throttled UI updates
    @Published var leftHand: HandLandmarks?
    @Published var rightHand: HandLandmarks?
    @Published var handsDetected = false

    // Audio pipeline callback — called on background queue every frame
    var onHandsDetected: ((HandLandmarks?, HandLandmarks?) -> Void)?

    private let request: VNDetectHumanHandPoseRequest = {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 2
        return req
    }()

    private var lastUIUpdate: CFAbsoluteTime = 0
    private let uiUpdateInterval: CFAbsoluteTime = 1.0 / 15.0

    /// Runs Vision hand pose detection on a camera frame. Called on background queue.
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observations = request.results, !observations.isEmpty else {
            onHandsDetected?(nil, nil)
            throttledUIUpdate(left: nil, right: nil)
            return
        }

        var left: HandLandmarks?
        var right: HandLandmarks?

        for observation in observations {
            guard let landmarks = HandLandmarks(from: observation) else { continue }

            switch observation.chirality {
            case .left:
                left = landmarks
            case .right:
                right = landmarks
            default:
                if left == nil { left = landmarks }
                else if right == nil { right = landmarks }
            }
        }

        // Audio pipeline — every frame, stays on background queue
        onHandsDetected?(left, right)

        // UI updates — throttled to ~15fps
        throttledUIUpdate(left: left, right: right)
    }

    private func throttledUIUpdate(left: HandLandmarks?, right: HandLandmarks?) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastUIUpdate >= uiUpdateInterval else { return }
        lastUIUpdate = now

        DispatchQueue.main.async { [weak self] in
            self?.leftHand = left
            self?.rightHand = right
            self?.handsDetected = left != nil || right != nil
        }
    }
}
