import SwiftUI

struct HandDebugOverlayView: View {
    let leftHand: HandLandmarks?
    let rightHand: HandLandmarks?

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                if let left = leftHand {
                    drawHand(context: context, size: size, hand: left, color: .cyan)
                }
                if let right = rightHand {
                    drawHand(context: context, size: size, hand: right, color: .orange)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawHand(context: GraphicsContext, size: CGSize, hand: HandLandmarks, color: Color) {
        let points = hand.allPoints

        // Draw bones
        for (from, to) in HandLandmarks.boneConnections {
            let p1 = viewPoint(points[from], in: size)
            let p2 = viewPoint(points[to], in: size)
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 2)
        }

        // Draw joints
        for point in points {
            let vp = viewPoint(point, in: size)
            let rect = CGRect(x: vp.x - 4, y: vp.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func viewPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: (1.0 - p.y) * size.height)
    }
}
