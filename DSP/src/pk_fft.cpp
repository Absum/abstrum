#include "pk_fft.h"

#include <cmath>

namespace pk {

void fft(std::vector<Complex> &a) {
    const size_t n = a.size();
    for (size_t i = 1, j = 0; i < n; ++i) {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(a[i], a[j]);
    }
    for (size_t len = 2; len <= n; len <<= 1) {
        const double ang = -2.0 * M_PI / double(len);
        const Complex wlen{float(std::cos(ang)), float(std::sin(ang))};
        for (size_t i = 0; i < n; i += len) {
            Complex w{1.0f, 0.0f};
            for (size_t k = 0; k < len / 2; ++k) {
                const Complex u = a[i + k];
                const Complex t = a[i + k + len / 2];
                const Complex v{t.re * w.re - t.im * w.im, t.re * w.im + t.im * w.re};
                a[i + k] = {u.re + v.re, u.im + v.im};
                a[i + k + len / 2] = {u.re - v.re, u.im - v.im};
                w = {w.re * wlen.re - w.im * wlen.im, w.re * wlen.im + w.im * wlen.re};
            }
        }
    }
}

}  // namespace pk
