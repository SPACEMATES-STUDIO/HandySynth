import Vision
import Combine

class HandTrackingManager: ObservableObject {
    // Throttled UI updates
    @Published var leftHand: HandLandmarks?
    @Published var rightHand: HandLandmarks?
    @Published var handsDetected = false
    @Published var bodyLandmarks: BodyLandmarks?

    // Audio pipeline callback — called on background queue every frame
    var onHandsDetected: ((HandLandmarks?, HandLandmarks?) -> Void)?

    var bodyTrackingEnabled = false

    private let handRequest: VNDetectHumanHandPoseRequest = {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 2
        return req
    }()

    private let bodyRequest = VNDetectHumanBodyPoseRequest()

    private var lastUIUpdate: CFAbsoluteTime = 0
    private let uiUpdateInterval: CFAbsoluteTime = 1.0 / 15.0

    /// Runs Vision hand pose detection on a camera frame. Called on background queue.
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        var requests: [VNRequest] = [handRequest]
        if bodyTrackingEnabled {
            requests.append(bodyRequest)
        }

        do {
            try handler.perform(requests)
        } catch {
            return
        }

        // Body pose
        if bodyTrackingEnabled, let bodyObs = bodyRequest.results?.first {
            let body = BodyLandmarks(from: bodyObs)
            throttledBodyUpdate(body)
        } else if bodyTrackingEnabled {
            throttledBodyUpdate(nil)
        }

        guard let observations = handRequest.results, !observations.isEmpty else {
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

    private var lastBodyUpdate: CFAbsoluteTime = 0

    private func throttledBodyUpdate(_ body: BodyLandmarks?) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastBodyUpdate >= uiUpdateInterval else { return }
        lastBodyUpdate = now

        DispatchQueue.main.async { [weak self] in
            self?.bodyLandmarks = body
        }
    }
}
