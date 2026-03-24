import Foundation
import Accelerate

final class FFTAnalyzer {
    private let bandsLock = NSLock()
    private var _bands: [Float]
    var bands: [Float] {
        get { bandsLock.withLock { _bands } }
    }

    private let fftSize: Int
    private let bandCount: Int
    private let sampleRate: Double

    private var fftSetup: vDSP_DFT_Setup?
    private var hannWindow: [Float]
    private var previousBands: [Float]

    private var realIn:     [Float]
    private var imagIn:     [Float]
    private var realOut:    [Float]
    private var imagOut:    [Float]
    private var magnitudes: [Float]

    private var sampleBuffer: [Float] = []
    private let smoothingFactor: Float = 0.5

    init(fftSize: Int = 1024, bandCount: Int = 32, sampleRate: Double = 44100) {
        self.fftSize    = fftSize
        self.bandCount  = bandCount
        self.sampleRate = sampleRate
        self._bands        = [Float](repeating: 0, count: bandCount)
        self.previousBands = [Float](repeating: 0, count: bandCount)
        self.hannWindow    = [Float](repeating: 0, count: fftSize)
        self.realIn        = [Float](repeating: 0, count: fftSize / 2)
        self.imagIn        = [Float](repeating: 0, count: fftSize / 2)
        self.realOut       = [Float](repeating: 0, count: fftSize / 2)
        self.imagOut       = [Float](repeating: 0, count: fftSize / 2)
        self.magnitudes    = [Float](repeating: 0, count: fftSize / 2)

        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
    }

    func analyze(samples: [Float]) {
        sampleBuffer.append(contentsOf: samples)
        guard sampleBuffer.count >= fftSize, let setup = fftSetup else { return }
        defer { sampleBuffer.removeFirst(min(fftSize / 2, sampleBuffer.count)) }

        var windowed = Array(sampleBuffer.prefix(fftSize))
        vDSP_vmul(windowed, 1, hannWindow, 1, &windowed, 1, vDSP_Length(fftSize))

        let halfSize = fftSize / 2
        for i in 0..<halfSize {
            realIn[i] = windowed[i * 2]
            imagIn[i] = windowed[i * 2 + 1]
        }

        vDSP_DFT_Execute(setup, realIn, imagIn, &realOut, &imagOut)

        realOut.withUnsafeMutableBufferPointer { realBuf in
            imagOut.withUnsafeMutableBufferPointer { imagBuf in
                magnitudes.withUnsafeMutableBufferPointer { magBuf in
                    var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    vDSP_zvabs(&split, 1, magBuf.baseAddress!, 1, vDSP_Length(halfSize))
                }
            }
        }

        var scale = Float(1.0 / Float(fftSize))
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))

        let newBands = logBands(from: magnitudes)

        var smoothed = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            smoothed[i] = previousBands[i] * smoothingFactor + newBands[i] * (1 - smoothingFactor)
        }
        previousBands = smoothed
        bandsLock.withLock { _bands = smoothed }
    }

    private func logBands(from magnitudes: [Float]) -> [Float] {
        let nyquist = sampleRate / 2.0
        let binHz   = nyquist / Double(magnitudes.count)
        let logMin  = log10(20.0)
        let logMax  = log10(20_000.0)
        let logStep = (logMax - logMin) / Double(bandCount)

        var result = [Float](repeating: 0, count: bandCount)
        for b in 0..<bandCount {
            let freqLow  = pow(10.0, logMin + Double(b)     * logStep)
            let freqHigh = pow(10.0, logMin + Double(b + 1) * logStep)
            let binLow   = max(0, Int(freqLow  / binHz))
            let binHigh  = min(magnitudes.count - 1, Int(freqHigh / binHz))
            guard binHigh >= binLow else { continue }
            let slice = Array(magnitudes[binLow...binHigh])
            var peak: Float = 0
            vDSP_maxv(slice, 1, &peak, vDSP_Length(slice.count))
            result[b] = peak
        }

        var maxVal: Float = 0
        vDSP_maxv(result, 1, &maxVal, vDSP_Length(bandCount))
        if maxVal > 0 {
            var divisor = maxVal
            vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(bandCount))
        }
        return result
    }
}
