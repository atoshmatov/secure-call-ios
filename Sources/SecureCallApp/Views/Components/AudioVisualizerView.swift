import SwiftUI

public struct AudioVisualizerView: View {
    public let amplitude: Float
    public let isMuted: Bool

    private let barCount = 20

    public init(amplitude: Float, isMuted: Bool) {
        self.amplitude = amplitude
        self.isMuted = isMuted
    }

    public var body: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<barCount, id: \.self) { i in
                let baseHeight: CGFloat = calculateHeight(for: i)
                let color: Color = barColor(for: amplitude)

                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .frame(width: 3.5, height: max(baseHeight, 4.0))
                    .animation(.easeInOut(duration: 0.1), value: amplitude)
            }
        }
        .frame(height: 44)
    }

    private func calculateHeight(for index: Int) -> CGFloat {
        if isMuted { return 4.0 }
        let waveOffset = sin((Double(index) / Double(barCount)) * .pi) * 0.6 + 0.4
        let rawHeight = CGFloat(amplitude * 1.6 * Float(waveOffset)) * 44.0
        return max(rawHeight, 5.0)
    }

    private func barColor(for amp: Float) -> Color {
        if isMuted {
            return Color(hex: 0x334155)
        } else if amp > 0.05 {
            return .nordicEmerald
        } else {
            return .sapphireBlue.opacity(0.6)
        }
    }
}
