#include "pitch_detector.h"

#include <algorithm>
#include <cmath>
#include <vector>

// YIN pitch detector (de Cheveigné & Kawahara, 2002).
// Monophonic, designed for guitar's fundamental range. The whole class of
// "is the note right?" feedback in Pickup is built on this estimate.

namespace {
// Below this normalized difference a tau is accepted as the period.
constexpr float kThreshold = 0.15f;
// If nothing dips below kThreshold (common for real, harmonically-rich guitar
// notes), fall back to the global CMND minimum as long as it's below this
// ceiling — so the tuner reports a best estimate instead of "no pitch".
constexpr float kFallbackCeiling = 0.55f;
// Default RMS silence gate (overridable via pk_pitch_detector_set_gate from the
// global AudioSettings). Kept low so quiet input still registers; the YIN
// aperiodicity threshold below is what actually rejects non-pitched noise.
constexpr float kDefaultRmsGate = 0.0025f;
// Plausible fundamental range (Hz). Guitar low E ~82 Hz; leave headroom.
constexpr float kMinFreq = 40.0f;
constexpr float kMaxFreq = 2000.0f;
}  // namespace

struct PKPitchDetector {
  double sampleRate;
  float gate;
  std::vector<float> yin;  // reused scratch buffer
};

PKPitchDetector *pk_pitch_detector_create(double sampleRate) {
  auto *d = new PKPitchDetector();
  d->sampleRate = sampleRate > 0.0 ? sampleRate : 44100.0;
  d->gate = kDefaultRmsGate;
  return d;
}

void pk_pitch_detector_destroy(PKPitchDetector *detector) { delete detector; }

void pk_pitch_detector_set_gate(PKPitchDetector *detector, float rmsGate) {
  if (detector && rmsGate >= 0.0f) detector->gate = rmsGate;
}

float pk_pitch_detector_process(PKPitchDetector *detector,
                                const float *samples,
                                size_t count,
                                float *outClarity) {
  if (outClarity) *outClarity = 0.0f;
  if (!detector || !samples || count < 4) return -1.0f;

  // Silence gate.
  double sumSquares = 0.0;
  for (size_t i = 0; i < count; ++i) sumSquares += double(samples[i]) * samples[i];
  const double rms = std::sqrt(sumSquares / double(count));
  if (rms < detector->gate) return -1.0f;

  // The integration window stays count/2 (standard YIN), but there is no point
  // computing lags beyond the lowest plausible fundamental — cap tau at
  // sampleRate/kMinFreq (~halves the O(N²) work at typical buffer sizes).
  //
  // Deliberate: the dip search still starts at tau=2, NOT at sampleRate/kMaxFreq.
  // If a too-high tone (> kMaxFreq) is periodic, its true period lands below the
  // valid range and the final range check rejects the frame — which is correct.
  // Constraining the search to the valid range instead would lock onto the
  // tone's 2× period and misreport it an octave down (subharmonic aliasing).
  const size_t tauMax = count / 2;
  const size_t tauCap =
      std::min(tauMax, size_t(detector->sampleRate / double(kMinFreq)) + 2);
  std::vector<float> &yin = detector->yin;
  yin.assign(tauCap, 0.0f);

  // Step 1: difference function.
  for (size_t tau = 1; tau < tauCap; ++tau) {
    float sum = 0.0f;
    for (size_t i = 0; i < tauMax; ++i) {
      const float delta = samples[i] - samples[i + tau];
      sum += delta * delta;
    }
    yin[tau] = sum;
  }

  // Step 2: cumulative mean normalized difference.
  yin[0] = 1.0f;
  float runningSum = 0.0f;
  for (size_t tau = 1; tau < tauCap; ++tau) {
    runningSum += yin[tau];
    yin[tau] = (runningSum == 0.0f) ? 1.0f : yin[tau] * float(tau) / runningSum;
  }

  // Step 3: absolute threshold — first dip below threshold, descend to its min.
  size_t tauEstimate = 0;
  for (size_t tau = 2; tau < tauCap; ++tau) {
    if (yin[tau] < kThreshold) {
      while (tau + 1 < tauCap && yin[tau + 1] < yin[tau]) ++tau;
      tauEstimate = tau;
      break;
    }
  }
  if (tauEstimate == 0) {
    // No clear dip — take the global minimum if it's still periodic enough.
    float best = 2.0f;
    for (size_t tau = 2; tau < tauCap; ++tau) {
      if (yin[tau] < best) { best = yin[tau]; tauEstimate = tau; }
    }
    if (tauEstimate == 0 || best > kFallbackCeiling) return -1.0f;
  }

  // Step 4: parabolic interpolation around the chosen tau for sub-sample accuracy.
  float betterTau = float(tauEstimate);
  const size_t x0 = (tauEstimate > 0) ? tauEstimate - 1 : tauEstimate;
  const size_t x2 = (tauEstimate + 1 < tauCap) ? tauEstimate + 1 : tauEstimate;
  if (x0 == tauEstimate) {
    betterTau = (yin[tauEstimate] <= yin[x2]) ? float(tauEstimate) : float(x2);
  } else if (x2 == tauEstimate) {
    betterTau = (yin[tauEstimate] <= yin[x0]) ? float(tauEstimate) : float(x0);
  } else {
    const float s0 = yin[x0];
    const float s1 = yin[tauEstimate];
    const float s2 = yin[x2];
    const float denom = 2.0f * s1 - s2 - s0;
    betterTau = (denom != 0.0f) ? float(tauEstimate) + (s2 - s0) / (2.0f * denom)
                                : float(tauEstimate);
  }

  const float freq = float(detector->sampleRate / betterTau);
  if (outClarity) *outClarity = 1.0f - yin[tauEstimate];
  if (freq < kMinFreq || freq > kMaxFreq) return -1.0f;
  return freq;
}
