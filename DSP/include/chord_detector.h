/*
 * Pickup DSP core — chroma (pitch-class) features for chord recognition.
 *
 * Computes a 12-bin chromagram from a buffer of mono samples: an FFT magnitude
 * spectrum folded onto the 12 pitch classes (C..B). Template matching against
 * a specific chord is done by the caller. Portable C ABI so it is shared with a
 * future Android build via the NDK, like the pitch detector.
 */
#ifndef PICKUP_CHORD_DETECTOR_H
#define PICKUP_CHORD_DETECTOR_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PKChordDetector PKChordDetector;

PKChordDetector *pk_chord_detector_create(double sampleRate);
void pk_chord_detector_destroy(PKChordDetector *detector);

/* Override the RMS silence gate (default set at creation). */
void pk_chord_detector_set_gate(PKChordDetector *detector, float rmsGate);

/*
 * Fill outChroma12 (must hold 12 floats) with a normalized chromagram
 * (max bin == 1). Returns 1 if there was enough signal, 0 on silence/invalid.
 */
int pk_chord_detector_chroma(PKChordDetector *detector,
                             const float *samples,
                             size_t count,
                             float *outChroma12);

#ifdef __cplusplus
}
#endif

#endif /* PICKUP_CHORD_DETECTOR_H */
