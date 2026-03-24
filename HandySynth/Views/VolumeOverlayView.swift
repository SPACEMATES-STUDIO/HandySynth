import SwiftUI

struct VolumeOverlayView: View {
    let volume: Float
    let isMuted: Bool

    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 20
            let barX = (size.width - barWidth) / 2
            let topPadding: CGFloat = 20
            let bottomPadding: CGFloat = 20
            let barHeight = size.height - topPadding - bottomPadding

            // Background track
            let bgRect = CGRect(x: barX, y: topPadding, width: barWidth, height: barHeight)
            context.fill(
                Path(roundedRect: bgRect, cornerRadius: 4),
                with: .color(.white.opacity(0.15))
            )

            // Fill level
            let fillHeight = barHeight * CGFloat(isMuted ? 0 : volume)
            let fillRect = CGRect(
                x: barX,
                y: topPadding + barHeight - fillHeight,
                width: barWidth,
                height: fillHeight
            )
            let gradient = Gradient(colors: [.green, .yellow, .orange, .red])
            context.fill(
                Path(roundedRect: fillRect, cornerRadius: 4),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: barX, y: topPadding + barHeight),
                    endPoint: CGPoint(x: barX, y: topPadding)
                )
            )

            // Label
            let label = isMuted ? "MUTE" : "\(Int(volume * 100))%"
            let labelColor: Color = isMuted ? .red : .white.opacity(0.7)
            context.draw(
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(labelColor),
                at: CGPoint(x: size.width / 2, y: 10)
            )
        }
        .frame(width: 36)
        .padding(.vertical, 60)
        .padding(.trailing, 8)
        .allowsHitTesting(false)
    }
}
