# Abstrum

Learn guitar by playing — a native iOS app that listens to you play and gives instant feedback.

See [SPEC.md](./SPEC.md) for the full product & technical spec.

## Architecture

- **Platform:** Native iOS (iPhone + iPad, universal), SwiftUI. Android may follow later.
- **Listening engine:** mic capture via `AVAudioEngine`, feeding a **portable C++ DSP core**
  (`DSP/`) over a flat C ABI. Keeping the DSP in C++ means a future Android build reuses
  the same engine via the NDK rather than rewriting it.
- **Phase 0 (current):** chromatic tuner — the simplest use of the listening engine and the
  way we validate detection accuracy before building any further UI.

```
DSP/                     Portable C++ pitch-detection core (YIN)
Abstrum/
  App/                   App entry + root view
  Audio/                 AVAudioEngine capture + Swift wrapper over the C++ core
  Core/                  Note/frequency math
  Tuner/                 Chromatic tuner UI
  Abstrum-Bridging-Header.h
project.yml              XcodeGen project definition (the .xcodeproj is generated)
```

## Building

Requires Xcode, plus [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`).
The `.xcodeproj` is generated and git-ignored.

```sh
xcodegen generate          # regenerate Abstrum.xcodeproj from project.yml
open Abstrum.xcodeproj       # then build/run from Xcode, or:

xcodebuild -project Abstrum.xcodeproj -scheme Abstrum \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run `xcodegen generate` again whenever you add or remove source files.
