import Testing
@testable import TrackPeek

@Suite("Audio spectrum")
struct AudioSpectrumTests {
    @Test("clamps analyzer samples and pads missing bands")
    func clampsAndPadsSamples() {
        let spectrum = AudioSpectrum(samples: [-0.4, 0.25, 1.4])

        #expect(spectrum[0] == 0)
        #expect(spectrum[1] == 0.25)
        #expect(spectrum[2] == 1)
        #expect(spectrum[6] == 0)
    }

    @Test("supports continuous interpolation between analyzer updates")
    func supportsInterpolation() {
        var midpoint = AudioSpectrum.zero
            + AudioSpectrum(samples: [1, 0.8, 0.6, 0.4, 0.2, 0.1, 0.05])
        midpoint.scale(by: 0.5)

        #expect(midpoint[0] == 0.5)
        #expect(abs(midpoint[3] - 0.2) < 0.000_001)
        #expect(abs(midpoint[6] - 0.025) < 0.000_001)
    }

    @Test("keeps a calm visible shape without audio permission")
    func keepsCalmRestingShape() {
        #expect(AudioSpectrum.resting[0] > 0)
        #expect(AudioSpectrum.resting[3] > AudioSpectrum.resting[0])
        #expect(AudioSpectrum.resting[6] > 0)
    }
}
