import SwiftUI
import MetalKit

struct MetalVisualizerView: NSViewRepresentable {
    @Binding var renderer: VisualizerRenderer?
    var fftAnalyzer: FFTAnalyzer?

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        if let r = VisualizerRenderer(mtkView: view) {
            view.delegate = r
            r.bandSource = fftAnalyzer
            DispatchQueue.main.async { renderer = r }
        }
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        renderer?.bandSource = fftAnalyzer
    }
}
