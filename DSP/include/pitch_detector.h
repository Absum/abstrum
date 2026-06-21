/*
 * Abstrum DSP core — monophonic pitch detection (YIN).
 *
 * Portable C/C++ with a flat C ABI so it can be shared verbatim between the
 * iOS app (via the Swift bridging header) and a future Android build (via the
 * NDK). Keep this header free of C++ types so it stays importable from Swift.
 */
#ifndef ABSTRUM_PITCH_DETECTOR_H
#define ABSTRUM_PITCH_DETECTOR_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PKPitchDetector PKPitchDetector;

/* Create a detector for the given sample rate (Hz). Caller owns the result. */
PKPitchDetector *pk_pitch_detector_create(double sampleRate);

/* Free a detector created by pk_pitch_detector_create. Safe to pass NULL. */
void pk_pitch_detector_destroy(PKPitchDetector *detector);

/* Override the RMS silence gate (default set at creation). */
void pk_pitch_detector_set_gate(PKPitchDetector *detector, float rmsGate);

/*
 * Estimate the fundamental frequency of `count` mono float samples.
 * Returns the frequency in Hz, or a negative value when no confident pitch is
 * found (silence, noise, or out of instrument range).
 * If outClarity is non-NULL it receives a 0..1 confidence estimate.
 */
float pk_pitch_detector_process(PKPitchDetector *detector,
                                const float *samples,
                                size_t count,
                                float *outClarity);

#ifdef __cplusplus
}
#endif

#endif /* ABSTRUM_PITCH_DETECTOR_H */
