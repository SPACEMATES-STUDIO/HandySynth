import Foundation

class SmoothingFilter {
    private var value: Float
    var factor: Float

    init(factor: Float = 0.7, initialValue: Float = 0.0) {
        self.factor = factor
        self.value = initialValue
    }

    func smooth(_ newValue: Float) -> Float {
        value = value * factor + newValue * (1.0 - factor)
        return value
    }

    func reset(to newValue: Float) {
        value = newValue
    }

    var current: Float { value }
}
