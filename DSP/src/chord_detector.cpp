#include "chord_detector.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "pk_fft.h"

// Chromagram for chord recognition: Hann-windowed FFT magnitude spectrum folded
// onto 12 pitch classes. Octave harmonics of a chord's notes reinforce the same
// pitch classes, so a strummed chord lands on its triad's classes.

namespace {

using pk::Complex;

constexpr float kDefaultRmsGate = 0.0025f;  // overridable via set_gate
constexpr double kMinFreq = 70.0;    // focus on the guitar range
constexpr double kMaxFreq = 1200.0;
// Analysis window: at 44.1 kHz this is ~0.19s and ~5.4 Hz/bin. Adjacent low
// fundamentals (E2 vs F2, 4.9 Hz apart) blur at any practical window — the
// discrimination actually comes from their harmonics, which land in
// well-resolved bins and fold to the same pitch class — so favour response
// time over bin width. (Was 16384 ≈ 0.37s: chord changes felt laggy because
// the old chord dominated the window for a third of a second.)
constexpr size_t kFFT = 8192;

}  // namespace

struct PKChordDetector {
    double sampleRate;
    float gate;
    std::vector<float> ring;      // last kFFT samples
    size_t writePos;
    size_t filled;
    std::vector<Complex> fftBuf;  // reused scratch — no allocation per call
};

PKChordDetector *pk_chord_detector_create(double sampleRate) {
    auto *d = new PKChordDetector();
    d->sampleRate = sampleRate > 0.0 ? sampleRate : 44100.0;
    d->gate = kDefaultRmsGate;
    d->ring.assign(kFFT, 0.0f);
    d->writePos = 0;
    d->filled = 0;
    d->fftBuf.assign(kFFT, Complex{0.0f, 0.0f});
    return d;
}

void pk_chord_detector_destroy(PKChordDetector *detector) { delete detector; }

void pk_chord_detector_set_gate(PKChordDetector *detector, float rmsGate) {
    if (detector && rmsGate >= 0.0f) detector->gate = rmsGate;
}

size_t pk_chord_detector_window(void) { return kFFT; }

void pk_chord_detector_reset(PKChordDetector *detector) {
    if (!detector) return;
    // Forget buffered audio so a new target chord starts from a clean window —
    // otherwise the previous chord dominates the analysis for the whole
    // window length after a change.
    detector->writePos = 0;
    detector->filled = 0;
    std::fill(detector->ring.begin(), detector->ring.end(), 0.0f);
}

int pk_chord_detector_chroma(PKChordDetector *detector,
                             const float *samples,
                             size_t count,
                             float *outChroma12) {
    for (int i = 0; i < 12; ++i) outChroma12[i] = 0.0f;
    if (!detector || !samples) return 0;

    // Accumulate into the ring buffer (chords need a longer window than a buffer).
    for (size_t i = 0; i < count; ++i) {
        detector->ring[detector->writePos] = samples[i];
        detector->writePos = (detector->writePos + 1) % kFFT;
        if (detector->filled < kFFT) detector->filled++;
    }
    if (detector->filled < kFFT) return 0;  // not enough audio yet

    const size_t n = kFFT;
    const size_t start = detector->writePos;  // oldest sample (ring is full)

    double sumSquares = 0.0;
    for (size_t i = 0; i < n; ++i) sumSquares += double(detector->ring[i]) * detector->ring[i];
    if (std::sqrt(sumSquares / double(n)) < detector->gate) return 0;

    std::vector<Complex> &buf = detector->fftBuf;
    for (size_t i = 0; i < n; ++i) {
        const double window = 0.5 * (1.0 - std::cos(2.0 * M_PI * double(i) / double(n - 1)));
        buf[i] = {float(detector->ring[(start + i) % kFFT] * window), 0.0f};
    }
    pk::fft(buf);

    const double sr = detector->sampleRate;
    for (size_t k = 1; k < n / 2; ++k) {
        const double freq = double(k) * sr / double(n);
        if (freq < kMinFreq || freq > kMaxFreq) continue;
        const double mag = std::sqrt(double(buf[k].re) * buf[k].re + double(buf[k].im) * buf[k].im);
        const double midi = 69.0 + 12.0 * std::log2(freq / 440.0);
        const int pc = ((int(std::llround(midi)) % 12) + 12) % 12;
        outChroma12[pc] += float(mag);
    }

    float maxBin = 0.0f;
    for (int i = 0; i < 12; ++i) maxBin = std::max(maxBin, outChroma12[i]);
    if (maxBin <= 0.0f) return 0;
    for (int i = 0; i < 12; ++i) outChroma12[i] /= maxBin;
    return 1;
}
