import AVFoundation
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var cameraError: String?

    var frameHandler: ((CVPixelBuffer) -> Void)?

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.camerainstrument.camera", qos: .userInteractive)

    func startSession() {
        guard !isRunning else { return }
        processingQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    func stopSession() {
        processingQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            DispatchQueue.main.async {
                self.cameraError = "No front camera found"
            }
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            DispatchQueue.main.async {
                self.cameraError = "Camera access error: \(error.localizedDescription)"
            }
            session.commitConfiguration()
            return
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async {
            self.isRunning = true
            self.cameraError = nil
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameHandler?(pixelBuffer)
    }
}
