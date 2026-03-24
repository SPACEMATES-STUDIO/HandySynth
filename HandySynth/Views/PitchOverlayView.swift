import SwiftUI

struct PitchOverlayView: View {
    let currentPitch: Float
    let currentNoteName: String
    let isQuantized: Bool
    let scale: Scale
    let rootNote: RootNote
    let baseOctave: Int
    let octaveRange: Int

    var body: some View {
        Canvas { context, size in
            // Background bar
            let bgRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.fill(
                Path(roundedRect: bgRect, cornerRadius: 8),
                with: .color(.black.opacity(0.4))
            )

            let margin: CGFloat = 16
            let usableWidth = size.width - margin * 2

            // Note markers
            let notes = ScaleHelper.noteNamesInRange(
                baseOctave: baseOctave,
                octaveRange: octaveRange,
                rootNote: rootNote,
                scale: isQuantized ? scale : .chromatic
            )

            for note in notes {
                let xPos = margin + CGFloat(note.1) * usableWidth
                // Tick mark
                var tick = Path()
                tick.move(to: CGPoint(x: xPos, y: size.height - 4))
                tick.addLine(to: CGPoint(x: xPos, y: size.height - 12))
                context.stroke(tick, with: .color(.white.opacity(0.3)), lineWidth: 1)

                // Note name
                context.draw(
                    Text(note.0)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5)),
                    at: CGPoint(x: xPos, y: 12)
                )
            }

            // Current pitch indicator
            let indicatorX = margin + CGFloat(currentPitch) * usableWidth

            // Glow circle
            let glowRect = CGRect(x: indicatorX - 6, y: size.height - 18, width: 12, height: 12)
            context.fill(Path(ellipseIn: glowRect.insetBy(dx: -3, dy: -3)), with: .color(.cyan.opacity(0.3)))
            context.fill(Path(ellipseIn: glowRect), with: .color(.cyan))

            // Note name
            context.draw(
                Text(currentNoteName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan),
                at: CGPoint(x: indicatorX, y: 12)
            )
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .allowsHitTesting(false)
    }
}
