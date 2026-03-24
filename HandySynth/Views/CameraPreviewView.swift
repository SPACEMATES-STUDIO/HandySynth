import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraContainerView {
        CameraContainerView(session: session)
    }

    func updateNSView(_ nsView: CameraContainerView, context: Context) {}
}

class CameraContainerView: NSView {
    let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func makeBackingLayer() -> CALayer {
        previewLayer
    }
}
