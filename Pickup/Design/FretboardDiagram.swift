//
//  FretboardDiagram.swift
//  Compact fretboard chart. Renders open chords (nut at top) and movable shapes
//  up the neck (auto-windowed with a base-fret label). Takes one or more
//  positions, so it serves both single fretted notes and full chord shapes.
//  String 0 = low E on the left … string 5 = high e on the right.
//

import SwiftUI

struct FretboardDiagram: View {
    var positions: [FretPosition]
    var mutedStrings: [Int] = []
    var barre: Barre? = nil
    var fretCount: Int = 4
    var tint: Color = Theme.teal

    var body: some View {
        Canvas { ctx, size in
            let cols = 6
            let leftPad: CGFloat = 22, rightPad: CGFloat = 16
            let topPad: CGFloat = 22, bottomPad: CGFloat = 8
            let w = size.width - leftPad - rightPad
            let h = size.height - topPad - bottomPad
            let colGap = w / CGFloat(cols - 1)
            let rowGap = h / CGFloat(fretCount)

            let frettedFrets = positions.filter { $0.fret > 0 }.map { $0.fret }
            let maxFret = frettedFrets.max() ?? 0
            let isOpen = maxFret <= fretCount
            // The fret number of the first row of the grid.
            let firstFret = isOpen ? 1 : (frettedFrets.min() ?? 1)

            // Top line: a thick nut for open chords, a thin line + "Nfr" label otherwise.
            var top = Path()
            top.move(to: CGPoint(x: leftPad, y: topPad))
            top.addLine(to: CGPoint(x: leftPad + w, y: topPad))
            ctx.stroke(top, with: .color(.white.opacity(isOpen ? 0.85 : 0.4)),
                       lineWidth: isOpen ? 3 : 1)
            if !isOpen {
                ctx.draw(Text("\(firstFret)fr")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.frost.opacity(0.75)),
                         at: CGPoint(x: leftPad - 6, y: topPad + rowGap * 0.5), anchor: .trailing)
            }

            // Frets
            for f in 1...fretCount {
                let y = topPad + rowGap * CGFloat(f)
                var p = Path()
                p.move(to: CGPoint(x: leftPad, y: y))
                p.addLine(to: CGPoint(x: leftPad + w, y: y))
                ctx.stroke(p, with: .color(.white.opacity(0.16)), lineWidth: 1)
            }
            // Strings
            for s in 0..<cols {
                let x = leftPad + colGap * CGFloat(s)
                var p = Path()
                p.move(to: CGPoint(x: x, y: topPad))
                p.addLine(to: CGPoint(x: x, y: topPad + h))
                ctx.stroke(p, with: .color(.white.opacity(0.22)), lineWidth: 1)
            }

            // Barre bar (drawn under the finger dots).
            if let barre {
                let row = barre.fret - firstFret
                if row >= 0 && row < fretCount {
                    let y = topPad + rowGap * (CGFloat(row) + 0.5)
                    let x1 = leftPad + colGap * CGFloat(barre.fromString)
                    let x2 = leftPad + colGap * CGFloat(barre.toString)
                    let bar = CGRect(x: x1 - 9, y: y - 9, width: (x2 - x1) + 18, height: 18)
                    ctx.fill(Path(roundedRect: bar, cornerRadius: 9), with: .color(tint))
                }
            }

            // Markers
            for pos in positions where pos.string >= 0 && pos.string < cols {
                let x = leftPad + colGap * CGFloat(pos.string)
                if pos.fret == 0 {
                    if isOpen {
                        let r: CGFloat = 6
                        let rect = CGRect(x: x - r, y: topPad - 15 - r, width: 2 * r, height: 2 * r)
                        ctx.stroke(Path(ellipseIn: rect), with: .color(tint), lineWidth: 2)
                    }
                } else {
                    // Skip dots already covered by the barre.
                    if let barre, pos.fret == barre.fret,
                       pos.string >= barre.fromString, pos.string <= barre.toString { continue }
                    let row = pos.fret - firstFret
                    if row >= 0 && row < fretCount {
                        let y = topPad + rowGap * (CGFloat(row) + 0.5)
                        let r: CGFloat = 10
                        let rect = CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
                        ctx.fill(Path(ellipseIn: rect), with: .color(tint))
                    }
                }
            }

            // Muted strings: an X above the nut.
            for s in mutedStrings where s >= 0 && s < cols {
                let x = leftPad + colGap * CGFloat(s)
                let y = topPad - 15
                let d: CGFloat = 5
                var p = Path()
                p.move(to: CGPoint(x: x - d, y: y - d)); p.addLine(to: CGPoint(x: x + d, y: y + d))
                p.move(to: CGPoint(x: x - d, y: y + d)); p.addLine(to: CGPoint(x: x + d, y: y - d))
                ctx.stroke(p, with: .color(.white.opacity(0.5)), lineWidth: 2)
            }
        }
    }
}
