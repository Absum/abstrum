#include "onset_detector.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "pk_fft.h"

// Spectral-flux onset detection. Each hop we take a Hann-windowed FFT of the
// most recent window and sum the positive magnitude change since the previous
// frame, but only across the guitar band — that ignores the metronome click
// (~1.2–1.8 kHz) so playing in time doesn't get scored off the click's echo.
// A pluck produces a sharp flux spike; an adaptive threshold crossing (with a
// refractory gap) marks the onset, dated to the centre of the analysis window.

namespace {

constexpr size_t kWindow = 1024;      // ~23 ms at 44.1 kHz
constexpr size_t kHop = 512;          // ~12 ms hop → onset resolution
constexpr float kDefaultRmsGate = 0.0025f;
constexpr double kBandLow = 70.0;     // guitar fundamentals start ~82 Hz (E2)
constexpr double kBandHigh = 1100.0;  // below the 1200/1760 Hz metronome click
constexpr int kHistory = 43;          // ~0.5 s of flux for the moving threshold
constexpr int kRefractoryHops = 4;    // ≥ ~48 ms between onsets
constexpr float kThreshMult = 1.6f;   // flux must exceed mult × recent mean …
constexpr float kThreshBias = 1e-4f;  // … plus a small floor
constexpr int kWarmupHops = 8;        // settle the threshold before reporting
constexpr double kMinBandFraction = 0.20;  // ≥20% of energy must be in-band, so
                                           // high tones/clicks can't trigger

using pk::Complex;

}  // namespace

struct PKOnsetDetector {
    double sampleRate;
    float gate;
    size_t binLow, binHigh;          // band-limited flux range
    std::vector<float> hann;
    std::vector<float> ring;         // last kWindow samples
    size_t writePos;
    size_t filled;
    size_t sinceHop;                 // new samples since the last analysis
    std::vector<float> prevMag;      // previous frame's band magnitudes
    std::vector<float> history;      // recent flux values (ring)
    int histPos;
    int histCount;
    float lastFlux;
    int hopsSinceOnset;
    int hopsSeen;
    long long frames;                // total samples consumed
    std::vector<Complex> fftBuf;     // reused scratch — no allocation per hop
};

PKOnsetDetector *pk_onset_detector_create(double sampleRate) {
    auto *d = new PKOnsetDetector();
    d->sampleRate = sampleRate > 0.0 ? sampleRate : 44100.0;
    d->gate = kDefaultRmsGate;

    const double hzPerBin = d->sampleRate / double(kWindow);
    d->binLow = std::max<size_t>(1, size_t(kBandLow / hzPerBin));
    d->binHigh = std::min<size_t>(kWindow / 2, size_t(kBandHigh / hzPerBin) + 1);

    d->hann.resize(kWindow);
    for (size_t i = 0; i < kWindow; ++i)
        d->hann[i] = 0.5f * (1.0f - std::cos(2.0 * M_PI * double(i) / double(kWindow - 1)));

    d->ring.assign(kWindow, 0.0f);
    d->writePos = 0;
    d->filled = 0;
    d->sinceHop = 0;
    d->prevMag.assign(d->binHigh > d->binLow ? d->binHigh - d->binLow : 0, 0.0f);
    d->history.assign(kHistory, 0.0f);
    d->histPos = 0;
    d->histCount = 0;
    d->lastFlux = 0.0f;
    d->hopsSinceOnset = kRefractoryHops;
    d->hopsSeen = 0;
    d->frames = 0;
    d->fftBuf.assign(kWindow, Complex{0.0f, 0.0f});
    return d;
}

void pk_onset_detector_destroy(PKOnsetDetector *detector) { delete detector; }

void pk_onset_detector_set_gate(PKOnsetDetector *detector, float rmsGate) {
    if (detector && rmsGate >= 0.0f) detector->gate = rmsGate;
}

long long pk_onset_detector_frames(const PKOnsetDetector *detector) {
    return detector ? detector->frames : 0;
}

namespace {

// Analyse the current window; returns the band-limited positive flux and, via
// onset, whether this hop crossed the adaptive threshold (a new attack).
float analyze(PKOnsetDetector *d, bool &onset) {
    onset = false;

    // Copy the ring into time order (oldest first) and apply the Hann window.
    std::vector<Complex> &buf = d->fftBuf;
    double sumSq = 0.0;
    for (size_t i = 0; i < kWindow; ++i) {
        const float s = d->ring[(d->writePos + i) % kWindow];
        sumSq += double(s) * double(s);
        buf[i] = {s * d->hann[i], 0.0f};
    }
    const float rms = float(std::sqrt(sumSq / double(kWindow)));

    pk::fft(buf);

    // Positive spectral flux within the guitar band only, plus a check that the
    // energy actually lives in the band (rejects high tones / the click, whose
    // in-band content is just leakage, independent of how loud they are).
    float flux = 0.0f;
    bool inBand = false;
    if (rms >= d->gate) {
        double totalE = 0.0, bandE = 0.0;
        for (size_t k = 1; k < kWindow / 2; ++k) {
            const float mag = std::sqrt(buf[k].re * buf[k].re + buf[k].im * buf[k].im);
            totalE += double(mag) * double(mag);
            if (k >= d->binLow && k < d->binHigh) {
                bandE += double(mag) * double(mag);
                const float diff = mag - d->prevMag[k - d->binLow];
                if (diff > 0.0f) flux += diff;
                d->prevMag[k - d->binLow] = mag;
            }
        }
        inBand = totalE > 0.0 && (bandE / totalE) >= kMinBandFraction;
    } else {
        // Silence: decay the reference so the next note reads as a fresh attack.
        for (auto &m : d->prevMag) m = 0.0f;
    }

    // Adaptive threshold from the recent flux mean.
    float mean = 0.0f;
    if (d->histCount > 0) {
        for (int i = 0; i < d->histCount; ++i) mean += d->history[i];
        mean /= float(d->histCount);
    }
    const float threshold = mean * kThreshMult + kThreshBias;

    if (d->hopsSeen >= kWarmupHops && rms >= d->gate && inBand &&
        flux > threshold && d->lastFlux <= threshold &&
        d->hopsSinceOnset >= kRefractoryHops) {
        onset = true;
        d->hopsSinceOnset = 0;
    } else {
        d->hopsSinceOnset++;
    }

    // Push flux into the history ring.
    d->history[d->histPos] = flux;
    d->histPos = (d->histPos + 1) % kHistory;
    if (d->histCount < kHistory) d->histCount++;
    d->lastFlux = flux;
    d->hopsSeen++;
    return flux;
}

}  // namespace

int pk_onset_detector_process(PKOnsetDetector *detector,
                              const float *samples,
                              size_t count,
                              long long *outFrames,
                              int maxOut) {
    if (!detector || !samples || !outFrames || maxOut <= 0) {
        if (detector && samples) detector->frames += (long long)count;
        return 0;
    }

    int written = 0;
    for (size_t n = 0; n < count; ++n) {
        detector->ring[detector->writePos] = samples[n];
        detector->writePos = (detector->writePos + 1) % kWindow;
        if (detector->filled < kWindow) detector->filled++;
        detector->frames++;
        detector->sinceHop++;

        if (detector->sinceHop >= kHop && detector->filled >= kWindow) {
            detector->sinceHop = 0;
            bool onset = false;
            analyze(detector, onset);
            if (onset && written < maxOut) {
                // Date the onset to the centre of the analysis window.
                outFrames[written++] = detector->frames - (long long)(kWindow / 2);
            }
        }
    }
    return written;
}
