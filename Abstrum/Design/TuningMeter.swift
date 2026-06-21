//
//  TuningMeter.swift
//  Horizontal cents meter: tick scale with a glowing indicator that snaps to
//  teal when the note is in tune.
//

import SwiftUI

struct TuningMeter: View {
    var cents: Double      // typically clamped to ±50 for display
    var inTune: Bool
    var active: Bool       // is there a current reading at all

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let inset: CGFloat = 14
            let clamped = max(-50, min(50, cents))
            let x = w / 2 + CGFloat(clamped / 50) * (w / 2 - inset)
            let color = inTune ? Theme.teal : Theme.cyan

            ZStack {
                Canvas { ctx, size in
                    let count = 21
                    for i in 0..<count {
                        let t = CGFloat(i) / CGFloat(count - 1)
                        let px = inset + t * (size.width - inset * 2)
                        let isCenter = i == (count - 1) / 2
                        let isMajor = i % 5 == 0
                        let tickH = isCenter ? size.height * 0.62
                                  : (isMajor ? size.height * 0.40 : size.height * 0.22)
                        var p = Path()
                        p.move(to: CGPoint(x: px, y: size.height / 2 - tickH / 2))
                        p.addLine(to: CGPoint(x: px, y: size.height / 2 + tickH / 2))
                        ctx.stroke(p,
                                   with: .color(.white.opacity(isCenter ? 0.85 : (isMajor ? 0.4 : 0.18))),
                                   lineWidth: isCenter ? 2 : 1)
                    }
                }

                if active {
                    Capsule()
                        .fill(color)
                        .frame(width: 6, height: h * 0.88)
                        .shadow(color: color.opacity(0.9), radius: inTune ? 18 : 9)
                        .position(x: x, y: h / 2)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: cents)
                        .animation(.snappy, value: inTune)
                }
            }
        }
    }
}
