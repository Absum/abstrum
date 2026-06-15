/*
 * Pickup DSP core — note-onset (attack) detection via spectral flux.
 *
 * Streams mono samples through a Hann-windowed short-time FFT and measures the
 * positive spectral flux (frame-to-frame magnitude increase) within the guitar
 * band only, so a metronome click well above that band does not trigger a false
 * onset. Adaptive-threshold peak picking reports sample-accurate onset frames,
 * letting the caller grade how tight a pluck was to the beat. Portable C ABI so
 * it is shared with a future Android build via the NDK, like the other cores.
 */
#ifndef PICKUP_ONSET_DETECTOR_H
#define PICKUP_ONSET_DETECTOR_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PKOnsetDetector PKOnsetDetector;

PKOnsetDetector *pk_onset_detector_create(double sampleRate);
void pk_onset_detector_destroy(PKOnsetDetector *detector);

/* Override the RMS silence gate (default set at creation). */
void pk_onset_detector_set_gate(PKOnsetDetector *detector, float rmsGate);

/*
 * Feed `count` samples. Writes the absolute frame index (samples since the
 * detector was created) of each onset found in this chunk into outFrames,
 * up to maxOut. Returns the number written. Frame / sampleRate gives the
 * onset time in seconds since creation.
 */
int pk_onset_detector_process(PKOnsetDetector *detector,
                              const float *samples,
                              size_t count,
                              long long *outFrames,
                              int maxOut);

/* Total samples consumed since creation — a monotonic audio clock. */
long long pk_onset_detector_frames(const PKOnsetDetector *detector);

#ifdef __cplusplus
}
#endif

#endif /* PICKUP_ONSET_DETECTOR_H */
