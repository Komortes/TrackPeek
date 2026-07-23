struct AudioSpectrum: AdditiveArithmetic, Equatable, Sendable {
    static let bandCount = 7
    static let zero = AudioSpectrum(storage: .zero)
    static let resting = AudioSpectrum(
        values: [0.22, 0.31, 0.25, 0.36, 0.27, 0.32, 0.23]
    )

    private var storage: SIMD8<Double>

    init(samples: [Float]) {
        self.init(values: samples.map(Double.init))
    }

    init(values: [Double]) {
        var storage = SIMD8<Double>.zero
        for index in 0 ..< min(values.count, Self.bandCount) {
            storage[index] = min(max(values[index], 0), 1)
        }
        self.storage = storage
    }

    private init(storage: SIMD8<Double>) {
        self.storage = storage
    }

    subscript(index: Int) -> Double {
        storage[index]
    }

    static func + (lhs: AudioSpectrum, rhs: AudioSpectrum) -> AudioSpectrum {
        AudioSpectrum(storage: lhs.storage + rhs.storage)
    }

    static func - (lhs: AudioSpectrum, rhs: AudioSpectrum) -> AudioSpectrum {
        AudioSpectrum(storage: lhs.storage - rhs.storage)
    }

    mutating func scale(by rhs: Double) {
        storage *= rhs
    }

    var magnitudeSquared: Double {
        (0 ..< Self.bandCount).reduce(into: 0) { result, index in
            result += storage[index] * storage[index]
        }
    }
}
