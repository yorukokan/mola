import SwiftUI

/// Mola işareti: bara takılı iki plaka, birlikte "duraklat" simgesi
struct MolaMark: View {
    var size: CGFloat = 28
    var mono: Bool = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(mono ? Color.primary.opacity(0.45) : Ink.steel)
                .frame(width: size, height: max(1.5, size * 0.09))
            HStack(spacing: size * 0.16) {
                RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                    .fill(mono ? Color.primary : Plate.red.color)
                    .frame(width: size * 0.2, height: size * 0.72)
                RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                    .fill(mono ? Color.primary : Plate.blue.color)
                    .frame(width: size * 0.2, height: size * 0.72)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Küçük plaka noktası (rutin rengi)
struct PlateDot: View {
    var plate: Plate
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(plate.color)
            .overlay(Circle().fill(Color.white.opacity(0.9)).frame(width: size * 0.28, height: size * 0.28))
            .frame(width: size, height: size)
    }
}
