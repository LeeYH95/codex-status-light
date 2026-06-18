import SwiftUI
import CodexTrafficGlassCore

struct TrafficGlassRootView: View {
    @ObservedObject var store: CodexStatusStore
    @State private var panelVisible = true

    private var panelAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.88, blendDuration: 0.04)
    }

    private var windowWidth: Double {
        store.isExpanded ? CodexPanelMotion.expandedWidth : CodexPanelMotion.collapsedWidth
    }

    var body: some View {
        HStack(spacing: 10) {
            TrafficLightColumn(snapshot: store.snapshot)
                .overlay(alignment: .trailing) {
                    if !store.isExpanded {
                        Button {
                            expandPanel()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 24, height: 62)
                                .rotationEffect(.degrees(-90))
                                .background(.white.opacity(0.10), in: Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 11)
                        .help("展开")
                    }
                }

            if store.isExpanded, panelVisible {
                StatusGlassPanel(snapshot: store.snapshot) {
                    collapsePanel()
                }
                .transition(.panelReveal)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: windowWidth, height: CodexPanelMotion.windowHeight, alignment: .leading)
        .clipped()
        .onAppear {
            panelVisible = store.isExpanded
        }
    }

    private func expandPanel() {
        store.isExpanded = true
        panelVisible = false

        DispatchQueue.main.async {
            withAnimation(panelAnimation) {
                panelVisible = true
            }
        }
    }

    private func collapsePanel() {
        withAnimation(panelAnimation) {
            panelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + CodexPanelMotion.duration) {
            guard !panelVisible else {
                return
            }

            store.isExpanded = false
        }
    }
}

private struct PanelRevealModifier: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .offset(x: CodexPanelMotion.revealOffsetX * (1 - progress))
            .scaleEffect(
                CodexPanelMotion.collapsedScale + ((1 - CodexPanelMotion.collapsedScale) * progress),
                anchor: .leading
            )
    }
}

private extension AnyTransition {
    static var panelReveal: AnyTransition {
        .modifier(
            active: PanelRevealModifier(progress: 0),
            identity: PanelRevealModifier(progress: 1)
        )
    }
}

private struct TrafficLightColumn: View {
    let snapshot: CodexStatusSnapshot

    private var presentation: StatusPresentation {
        StatusPresentation.presentation(for: snapshot.state)
    }

    var body: some View {
        VStack(spacing: 15) {
            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 23, height: 3)

            LampView(
                color: Color(red: 1.0, green: 0.18, blue: 0.18),
                isActive: presentation.activeLamp == .red,
                isBlinking: presentation.activeLamp == .red && presentation.isBlinking
            )
            LampView(color: Color(red: 1.0, green: 0.77, blue: 0.18), isActive: presentation.activeLamp == .yellow)
            LampView(color: Color(red: 0.10, green: 0.86, blue: 0.38), isActive: presentation.activeLamp == .green)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(width: 78, height: 220)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.04, green: 0.06, blue: 0.07).opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.black.opacity(0.24), .black.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .stroke(.black.opacity(0.50), lineWidth: 1)
                )
        }
        .shadow(color: .black.opacity(0.42), radius: 22, y: 14)
        .help(presentation.compactLabel)
    }
}

private struct LampView: View {
    let color: Color
    let isActive: Bool
    var isBlinking: Bool = false
    @State private var blinkPhase = false

    var body: some View {
        let visualActive = isActive && (!isBlinking || blinkPhase)

        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.44), .white.opacity(0.08)],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                )
                .frame(width: 42, height: 42)
                .shadow(color: .white.opacity(0.12), radius: 1, x: -1, y: -1)

            Circle()
                .fill(
                    RadialGradient(
                        colors: lampColors,
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 28
                    )
                )
                .frame(width: 34, height: 34)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(visualActive ? 0.72 : 0.22))
                        .frame(width: 9, height: 9)
                        .blur(radius: visualActive ? 0.3 : 0.7)
                        .offset(x: 8, y: 7)
                }
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(visualActive ? 0.56 : 0.22), .black.opacity(0.22)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: color.opacity(visualActive ? 0.68 : 0), radius: 14)
                .shadow(color: color.opacity(visualActive ? 0.34 : 0), radius: 5)
        }
        .overlay {
            if visualActive {
                Circle()
                    .stroke(color.opacity(0.42), lineWidth: 1.5)
                    .frame(width: 42, height: 42)
                    .blur(radius: 2)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isActive)
        .animation(.easeInOut(duration: 0.52), value: blinkPhase)
        .onAppear {
            blinkPhase = true
            updateBlinking()
        }
        .onChange(of: isBlinking) { _, _ in
            updateBlinking()
        }
        .onChange(of: isActive) { _, _ in
            updateBlinking()
        }
    }

    private var lampColors: [Color] {
        let visualActive = isActive && (!isBlinking || blinkPhase)
        if visualActive {
            return [
                .white.opacity(0.82),
                color.opacity(0.98),
                color.opacity(0.76),
                color.opacity(0.48)
            ]
        } else {
            return [
                .white.opacity(0.28),
                color.opacity(0.18),
                Color(red: 0.16, green: 0.18, blue: 0.18).opacity(0.72),
                .black.opacity(0.42)
            ]
        }
    }

    private func updateBlinking() {
        guard isActive, isBlinking else {
            blinkPhase = isActive
            return
        }

        withAnimation(.easeInOut(duration: 0.52).repeatForever(autoreverses: true)) {
            blinkPhase = false
        }
    }
}

private struct StatusGlassPanel: View {
    let snapshot: CodexStatusSnapshot
    let onCollapse: () -> Void

    private var presentation: StatusPresentation {
        StatusPresentation.presentation(for: snapshot.state)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text("Codex 红绿灯")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 10)

                Button(action: onCollapse) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.13), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.70))
                .help("收起")
            }
            .padding(.horizontal, 18)
            .frame(height: 50)

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 5) {
                CurrentStatusCard(
                    label: "当前动态",
                    title: presentation.compactLabel,
                    detail: snapshot.detail,
                    state: snapshot.state,
                    updatedAt: snapshot.updatedAt
                )

                HStack(spacing: 12) {
                    QuotaCard(
                        title: "5 小时",
                        value: snapshot.quota.fiveHourRemainingPercent,
                        resetAt: snapshot.quota.fiveHourResetAt,
                        accent: Color(red: 0.35, green: 0.90, blue: 0.58)
                    )
                    QuotaCard(
                        title: "1 周",
                        value: snapshot.quota.weeklyRemainingPercent,
                        resetAt: snapshot.quota.weeklyResetAt,
                        accent: Color(red: 1.00, green: 0.73, blue: 0.20)
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 390, height: 242)
        .clipped()
        .background {
            PanelGlassShape()
        }
        .shadow(color: .black.opacity(0.34), radius: 22, y: 14)
    }

}

private struct PanelGlassShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(red: 0.035, green: 0.045, blue: 0.055).opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.08), .clear, .black.opacity(0.26)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22),
                                .white.opacity(0.07),
                                .black.opacity(0.38)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct CurrentStatusCard: View {
    let label: String
    let title: String
    let detail: String
    let state: CodexState
    let updatedAt: Date?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.62), radius: 7)

            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(StatusPresentation.freshnessLabel(updatedAt: updatedAt))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                }

                Text(detail)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 70)
        .background(cardBackground)
    }

    private var displayTitle: String {
        switch state {
        case .idle:
            "当前空闲"
        default:
            title
        }
    }

    private var statusColor: Color {
        switch StatusPresentation.presentation(for: state).activeLamp {
        case .red:
            Color(red: 1.0, green: 0.30, blue: 0.28)
        case .yellow:
            Color(red: 1.0, green: 0.78, blue: 0.20)
        case .green:
            Color(red: 0.26, green: 0.90, blue: 0.48)
        case nil:
            .white.opacity(0.42)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.34))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct QuotaCard: View {
    let title: String
    let value: Double?
    let resetAt: Date?
    let accent: Color

    private var normalizedValue: Double {
        min(100, max(0, value ?? 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))

                Spacer(minLength: 8)

                Text(resetLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
            }

            Text(value.map { "\(Int($0.rounded()))%" } ?? "--")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * normalizedValue / 100)
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var resetLabel: String {
        guard let resetAt else {
            return ""
        }

        let formatter = DateFormatter()
        if title == "5 小时" {
            formatter.dateFormat = "HH:mm"
            return "\(formatter.string(from: resetAt)) 重置"
        }

        formatter.dateFormat = "M月d日"
        return formatter.string(from: resetAt)
    }
}
