import Metal
import MetalKit
import simd

final class VisualizerRenderer: NSObject, MTKViewDelegate {

    private let bandCount = 32
    private let historyCount = 50

    // MARK: - Thread-safe state

    private let stateLock = NSLock()
    private var _bands: [Float]

    var bands: [Float] {
        get { stateLock.withLock { _bands } }
        set { stateLock.withLock { _bands = newValue } }
    }

    private var _colorPrimary:   SIMD4<Float> = SIMD4(0.0, 1.0, 0.6, 1.0)
    private var _colorSecondary: SIMD4<Float> = SIMD4(0.0, 0.3, 0.8, 1.0)
    private var _spectrumHeight: Float = 770.0
    private var _spacing:        Float = 20.0

    var colorPrimary: SIMD4<Float> {
        get { stateLock.withLock { _colorPrimary } }
        set { stateLock.withLock { _colorPrimary = newValue } }
    }
    // Band source — set after init, renderer reads bands in draw()
    weak var bandSource: FFTAnalyzer?

    var colorSecondary: SIMD4<Float> {
        get { stateLock.withLock { _colorSecondary } }
        set { stateLock.withLock { _colorSecondary = newValue } }
    }
    var spectrumHeight: Float {
        get { stateLock.withLock { _spectrumHeight } }
        set { stateLock.withLock { _spectrumHeight = newValue } }
    }
    var spacing: Float {
        get { stateLock.withLock { _spacing } }
        set { stateLock.withLock { _spacing = newValue } }
    }

    // MARK: - Metal objects

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var terrainPipeline: MTLRenderPipelineState?
    private var historyMetalBuffer: MTLBuffer?

    private var history: [[Float]] = []
    private var prevTerrainBands: [Float] = []
    private var startTime: CFTimeInterval = CACurrentMediaTime()

    // Terrain processing constants
    private let smoothingTimeConstant: Float = 0.03
    private let minDecibel: Float = -100
    private let maxDecibel: Float = -10
    private let smoothingPoints: Int = 9
    private let smoothingPasses: Int = 3

    // MARK: - Init

    init?(mtkView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue  = device.makeCommandQueue() else { return nil }
        self.device       = device
        self.commandQueue = queue
        self._bands       = [Float](repeating: 0, count: bandCount)

        super.init()

        let empty = [Float](repeating: 0, count: bandCount)
        history = Array(repeating: empty, count: historyCount)
        prevTerrainBands = empty
        historyMetalBuffer = device.makeBuffer(
            length: MemoryLayout<Float>.size * historyCount * bandCount,
            options: .storageModeShared)

        mtkView.device             = device
        mtkView.colorPixelFormat   = .bgra8Unorm_srgb
        mtkView.clearColor         = MTLClearColorMake(0, 0, 0, 1)
        mtkView.isPaused           = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.delegate           = self

        buildPipeline(for: mtkView)
    }

    private func buildPipeline(for view: MTKView) {
        guard let library = device.makeDefaultLibrary(),
              let vertFn  = library.makeFunction(name: "terrainVertex"),
              let fragFn  = library.makeFunction(name: "terrainFragment") else {
            print("[VisualizerRenderer] Could not find terrain shader functions")
            return
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vertFn
        desc.fragmentFunction = fragFn
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat

        let colorAtt = desc.colorAttachments[0]!
        colorAtt.isBlendingEnabled             = true
        colorAtt.sourceRGBBlendFactor          = .sourceAlpha
        colorAtt.sourceAlphaBlendFactor        = .one
        colorAtt.destinationRGBBlendFactor     = .oneMinusSourceAlpha
        colorAtt.destinationAlphaBlendFactor   = .zero

        do {
            terrainPipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            print("[VisualizerRenderer] Pipeline creation failed: \(error)")
        }
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable  = view.currentDrawable,
              let renderPass = view.currentRenderPassDescriptor,
              let cmdBuf    = commandQueue.makeCommandBuffer(),
              let encoder   = cmdBuf.makeRenderCommandEncoder(descriptor: renderPass),
              let pipeline  = terrainPipeline else { return }

        let (cp, cs, sh, sp) = stateLock.withLock {
            (_colorPrimary, _colorSecondary, _spectrumHeight, _spacing)
        }

        var currentBands = bandSource?.bands ?? bands
        let elapsed = Float(CACurrentMediaTime() - startTime)

        // Animated demo bars when silent
        let maxBand = currentBands.max() ?? 0
        if maxBand < 0.01 {
            for i in 0..<bandCount {
                let t = Float(i) / Float(bandCount)
                currentBands[i] = (sin(elapsed * 1.5 + t * 6.28) * 0.5 + 0.5) * 0.6 + 0.1
            }
        }

        // dB normalization
        if maxDecibel > minDecibel {
            for i in 0..<bandCount {
                let db = 20.0 * log10f(max(currentBands[i], 1e-7))
                currentBands[i] = max(0, min(1, (db - minDecibel) / (maxDecibel - minDecibel)))
            }
        }

        // Spatial smoothing
        let hw = max(0, smoothingPoints / 2)
        for _ in 0..<smoothingPasses {
            var smoothed = currentBands
            for i in 0..<bandCount {
                let lo = max(0, i - hw), hi = min(bandCount - 1, i + hw)
                var sum: Float = 0
                for j in lo...hi { sum += currentBands[j] }
                smoothed[i] = sum / Float(hi - lo + 1)
            }
            currentBands = smoothed
        }

        // Per-band EMA
        for i in 0..<bandCount {
            prevTerrainBands[i] = smoothingTimeConstant * prevTerrainBands[i] + (1 - smoothingTimeConstant) * currentBands[i]
        }
        currentBands = prevTerrainBands

        // Update history ring buffer
        history.removeFirst()
        history.append(currentBands)
        if let buf = historyMetalBuffer {
            let ptr = buf.contents().bindMemory(to: Float.self, capacity: historyCount * bandCount)
            for row in 0..<historyCount {
                for b in 0..<bandCount { ptr[row * bandCount + b] = history[row][b] }
            }
        }

        // Build uniforms
        let size = view.drawableSize
        var uniforms = VisualizerUniforms(
            time:           elapsed,
            bandCount:      UInt32(bandCount),
            viewportSize:   SIMD2<Float>(Float(size.width), Float(size.height)),
            colorPrimary:   cp,
            colorSecondary: cs,
            energy:         0.5,
            _pad0: 0, _pad1: 0, _pad2: 0
        )

        var tUni = TerrainUniforms(spectrumHeight: sh, spacing: sp, _pad0: 0, _pad1: 0)
        var hc = UInt32(historyCount)

        let vertexCount = historyCount * 2 * max(bandCount - 1, 0) * 6

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(historyMetalBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<VisualizerUniforms>.size, index: 1)
        encoder.setVertexBytes(&hc, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setVertexBytes(&tUni, length: MemoryLayout<TerrainUniforms>.size, index: 3)
        encoder.setFragmentBuffer(historyMetalBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VisualizerUniforms>.size, index: 1)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        encoder.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}
