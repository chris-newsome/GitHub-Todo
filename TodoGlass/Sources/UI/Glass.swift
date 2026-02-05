import SwiftUI

struct GlassBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let driftA = CGFloat(sin(t / 10)) * 30
            let driftB = CGFloat(cos(t / 12)) * 40
            let driftC = CGFloat(sin(t / 14)) * 24

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.82, green: 0.92, blue: 1.0),
                        Color(red: 0.95, green: 0.90, blue: 0.98),
                        Color(red: 0.86, green: 0.98, blue: 0.93),
                        Color(red: 0.98, green: 0.95, blue: 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 300, height: 300)
                    .blur(radius: 12)
                    .offset(x: -160 + driftA, y: -240 + driftB)

                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 240, height: 240)
                    .blur(radius: 10)
                    .offset(x: 190 + driftB, y: -60 + driftC)

                RoundedRectangle(cornerRadius: 120, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 360, height: 240)
                    .blur(radius: 14)
                    .rotationEffect(.degrees(18))
                    .offset(x: 40 + driftC, y: 260 + driftA)
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .opacity(0.6)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.6 : 0.3), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.2 : 0.4),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}
