import SwiftUI
import UIKit

// MARK: - Kart

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Ink.line, lineWidth: 0.5))
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardModifier(padding: padding)) }
}

// MARK: - Küçük başlık

struct Eyebrow: View {
    var text: String
    var color: Color = Ink.secondary

    var body: some View {
        Text(text.uppercased(with: Fmt.tr))
            .font(.system(size: 12, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(color)
    }
}

// MARK: - Büyük ana buton (başparmak bölgesi)

struct BigButtonStyle: ButtonStyle {
    var color: Color
    var foreground: Color = .white
    var height: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Ink.primary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Ink.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Kilo / tekrar girişi

struct StepButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button {
            Feedback.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

/// Büyük rakam + altında − / + butonları. Rakama dokununca klavyeyle yazılır.
struct ValueDial: View {
    var title: String
    var value: String
    var onMinus: () -> Void
    var onPlus: () -> Void
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Ink.secondary)
            Button(action: onTap) {
                Text(value)
                    .font(PFont.number(54, weight: .heavy))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                StepButton(systemImage: "minus", action: onMinus)
                StepButton(systemImage: "plus", action: onPlus)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Ink.surface2, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Dinlenmedeyken sıradaki seti düzenlemek için küçük − değer + satırı
struct MiniStepper: View {
    var value: String
    var unit: String
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                Feedback.tap()
                onMinus()
            } label: {
                Image(systemName: "minus").font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            VStack(spacing: 0) {
                Text(value).font(PFont.number(20, weight: .heavy))
                Text(unit).font(.system(size: 10, weight: .semibold)).foregroundStyle(Ink.secondary)
            }
            .frame(minWidth: 56)
            Button {
                Feedback.tap()
                onPlus()
            } label: {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
        }
        .foregroundStyle(Ink.primary)
        .background(Ink.surface2, in: Capsule())
    }
}

// MARK: - Halka

struct RingView: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().stroke(Ink.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Yardımcılar

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

func parseNumber(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
}
