/*
 * Abstrum DSP core — shared in-place FFT used by the chroma and onset
 * detectors. Internal C++ helper, not part of the C ABI. Single seam for a
 * future platform-accelerated backend (vDSP on Apple, etc.).
 */
#ifndef ABSTRUM_PK_FFT_H
#define ABSTRUM_PK_FFT_H

#include <vector>

namespace pk {

struct Complex {
    float re;
    float im;
};

/* Iterative radix-2 Cooley–Tukey FFT, in place. a.size() must be a power of two. */
void fft(std::vector<Complex> &a);

}  // namespace pk

#endif /* ABSTRUM_PK_FFT_H */
