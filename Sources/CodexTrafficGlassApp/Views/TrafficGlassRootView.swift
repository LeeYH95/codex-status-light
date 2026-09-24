import SwiftUI
import CodexTrafficGlassCore

struct TrafficGlassRootView: View {
    @ObservedObject var store: CodexStatusStore
    @State private var panelVisible = false
    @State private var hoverCollapseTask: Task<Void, Never>?

    private var panelAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.88, blendDuration: 0.04)
    }

    private var windowWidth: Double {
        store.isExpanded ? CodexPanelMotion.expandedWidth : CodexPanelMotion.collapsedWidth
    }

    private var windowHeight: Double {
        CodexPanelMotion.quotaReservoirWindowHeight
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: CodexPanelVisualMetrics.quotaGaugeSpacing) {
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

                CollapsedQuotaReservoir(quota: store.snapshot.quota)
            }
            .frame(
                width: 78,
                height: CodexPanelVisualMetrics.trafficLightWithReservoirHeight,
                alignment: .top
            )

            if store.isExpanded, panelVisible {
                StatusGlassPanel(snapshot: store.snapshot)
                .transition(.panelReveal)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: windowWidth, height: windowHeight, alignment: .topLeading)
        .clipped()
        .onHover { isHovering in
            handleHoverChange(isHovering)
        }
        .onAppear {
            panelVisible = store.isExpanded
        }
    }

    private func expandPanel() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil

        guard !store.isExpanded else {
            if !panelVisible {
                withAnimation(panelAnimation) {
                    panelVisible = true
                }
            }
            return
        }

        store.isExpanded = true
        panelVisible = false

        DispatchQueue.main.async {
            withAnimation(panelAnimation) {
                panelVisible = true
            }
        }
    }

    private func collapsePanel() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil

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

    private func handleHoverChange(_ isHovering: Bool) {
        if isHovering {
            expandPanel()
        } else {
            scheduleHoverCollapse()
        }
    }

    private func scheduleHoverCollapse() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = Task { @MainActor in
            let delayNanoseconds = UInt64(CodexPanelMotion.hoverCollapseDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            collapsePanel()
        }
    }
}

private struct CollapsedQuotaReservoir: View {
    let quota: CodexQuota
    @State private var wavePhase = 0.0

    private var remainingPercent: Double? {
        CollapsedQuotaReservoirPresentation.remainingPercent(for: quota)
    }

    private var progress: Double {
        WeeklyQuotaPresentation.normalizedRemainingProgress(for: remainingPercent)
    }

    private var waterColors: [Color] {
        switch WeeklyQuotaPresentation.remainingBand(for: remainingPercent) {
        case .ample:
            [
                Color(red: 0.49, green: 0.97, blue: 0.75).opacity(0.82),
                Color(red: 0.06, green: 0.70, blue: 0.42).opacity(0.88)
            ]
        case .caution:
            [
                Color(red: 1.00, green: 0.80, blue: 0.34).opacity(0.80),
                Color(red: 0.92, green: 0.48, blue: 0.10).opacity(0.86)
            ]
        case .critical:
            [
                Color(red: 1.00, green: 0.54, blue: 0.51).opacity(0.80),
                Color(red: 0.89, green: 0.20, blue: 0.26).opacity(0.88)
            ]
        case .unknown:
            [.white.opacity(0.36), .white.opacity(0.18)]
        }
    }

    private var waterGradient: LinearGradient {
        LinearGradient(colors: waterColors, startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: CodexPanelVisualMetrics.quotaReservoirCornerRadius,
                style: .continuous
            )
            .fill(.clear)
            .background {
                GlassBackground(cornerRadius: CodexPanelVisualMetrics.quotaReservoirCornerRadius)
            }
            .overlay(
                RoundedRectangle(
                    cornerRadius: CodexPanelVisualMetrics.quotaReservoirCornerRadius,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.48, green: 0.66, blue: 0.68).opacity(0.10),
                            Color(red: 0.008, green: 0.024, blue: 0.030).opacity(CodexSpatialGlassStyle.panelSmokeOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )

            LiquidWaveShape(level: progress, phase: wavePhase)
                .fill(waterGradient)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CodexPanelVisualMetrics.quotaReservoirCornerRadius - 1,
                        style: .continuous
                    )
                )
                .padding(1)

            Text(remainingPercent.map { "\(Int($0.rounded()))%" } ?? "--")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
                .shadow(color: Color.black.opacity(0.44), radius: 3, y: 1)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: CodexPanelVisualMetrics.quotaReservoirCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: CodexPanelVisualMetrics.quotaReservoirCornerRadius,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.26), .white.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .frame(
            width: CodexPanelVisualMetrics.quotaReservoirSize,
            height: CodexPanelVisualMetrics.quotaReservoirSize
        )
        .shadow(color: .black.opacity(0.38), radius: 9, y: 5)
        .onAppear {
            withAnimation(.linear(duration: 4.8).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .accessibilityLabel("5小时额度剩余")
        .accessibilityValue(remainingPercent.map { "\(Int($0.rounded()))%" } ?? "未知")
    }
}

private struct LiquidWaveShape: Shape {
    var level: Double
    var phase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, phase) }
        set {
            level = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let clampedLevel = min(1, max(0, level))
        guard clampedLevel > 0 else {
            return Path()
        }

        let waterline = rect.maxY - (rect.height * clampedLevel)
        let amplitude = min(1.6, rect.height * 0.04)
        let step = max(1, rect.width / 20)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: waterline))

        var x = rect.minX
        while x <= rect.maxX {
            let progress = (x - rect.minX) / rect.width
            let y = waterline + (sin((progress * .pi * 2) + phase) * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        let finalY = waterline + (sin(.pi * 2 + phase) * amplitude)
        path.addLine(to: CGPoint(x: rect.maxX, y: finalY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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

    static var resetDetailsReveal: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .topTrailing))
                .combined(with: .offset(y: -8)),
            removal: .opacity
                .combined(with: .scale(scale: 0.985, anchor: .topTrailing))
                .combined(with: .offset(y: -5))
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
                .fill(.clear)
                .background {
                    GlassBackground(cornerRadius: 32)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.26, green: 0.34, blue: 0.35).opacity(0.08),
                                    Color(red: 0.005, green: 0.014, blue: 0.018).opacity(CodexSpatialGlassStyle.panelSmokeOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(CodexSpatialGlassStyle.highlightOpacity),
                                    .white.opacity(0.07),
                                    .black.opacity(0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .shadow(color: .black.opacity(0.38), radius: 22, y: 14)
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
                .fill(Color.black.opacity(0.72))
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .black.opacity(0.46)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .frame(width: 42, height: 42)
                .shadow(color: .white.opacity(0.16), radius: 1, x: -1, y: -1)

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
    @State private var resetDetailsVisible = false
    @State private var resetDetailsPinned = false
    @State private var resetDetailsHideTask: Task<Void, Never>?

    private var presentation: StatusPresentation {
        StatusPresentation.presentation(for: snapshot.state)
    }

    private var resetDetailsAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.05)
    }

    private var resetCountLabel: String {
        BankedResetPresentation.summaryLabel(for: snapshot.quota)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Codex 红绿灯")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 10)

                    if !resetCountLabel.isEmpty {
                        ResetCountPill(
                            quota: snapshot.quota,
                            isActive: resetDetailsVisible
                        ) {
                            toggleResetDetailsPinned()
                        }
                        .onHover { isHovering in
                            handleResetDetailsHover(isHovering)
                        }
                    }

                }
                .padding(.horizontal, 18)
                .frame(height: CodexPanelVisualMetrics.headerHeight)

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: CodexPanelVisualMetrics.dividerHeight)

                VStack(spacing: CodexPanelVisualMetrics.moduleSpacing) {
                    CurrentStatusCard(
                        label: "当前动态",
                        title: presentation.compactLabel,
                        detail: snapshot.detail,
                        state: snapshot.state,
                        updatedAt: snapshot.updatedAt
                    )

                    QuotaCardsRow(quota: snapshot.quota)
                        .frame(height: CodexPanelVisualMetrics.quotaCardRowHeight)
                }
                .padding(CodexPanelVisualMetrics.panelContentInset)
            }
            .frame(width: 390, height: CodexPanelMotion.expandedPanelHeight)
            .clipped()
            .background {
                PanelGlassShape()
            }

            if resetDetailsVisible && !resetCountLabel.isEmpty {
                BankedResetDetailsPopover(quota: snapshot.quota)
                    .padding(.top, 58)
                    .padding(.trailing, 20)
                    .transition(.resetDetailsReveal)
                    .zIndex(2)
                    .onHover { isHovering in
                        handleResetDetailsHover(isHovering)
                    }
            }
        }
        .shadow(color: .black.opacity(0.34), radius: 22, y: 14)
    }

    private func handleResetDetailsHover(_ isHovering: Bool) {
        if isHovering {
            resetDetailsHideTask?.cancel()
            resetDetailsHideTask = nil
            withAnimation(resetDetailsAnimation) {
                resetDetailsVisible = true
            }
        } else {
            scheduleResetDetailsHide()
        }
    }

    private func toggleResetDetailsPinned() {
        resetDetailsHideTask?.cancel()
        resetDetailsHideTask = nil
        resetDetailsPinned.toggle()
        withAnimation(resetDetailsAnimation) {
            resetDetailsVisible = resetDetailsPinned
        }
    }

    private func scheduleResetDetailsHide() {
        guard !resetDetailsPinned else {
            return
        }

        resetDetailsHideTask?.cancel()
        resetDetailsHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else {
                return
            }
            withAnimation(resetDetailsAnimation) {
                resetDetailsVisible = false
            }
        }
    }

}

private struct ResetCountPill: View {
    let quota: CodexQuota
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .black))

                Text(BankedResetPresentation.summaryLabel(for: quota))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(isActive ? 0.92 : 0.70))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetCountCornerRadius, style: .continuous)
                    .fill(Color(red: 0.075, green: 0.09, blue: 0.10).opacity(isActive ? 0.82 : 0.68))
                    .overlay(
                        RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetCountCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isActive ? 0.09 : 0.045),
                                        .black.opacity(isActive ? 0.16 : 0.24)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetCountCornerRadius, style: .continuous)
                            .stroke(.white.opacity(isActive ? CodexSpatialGlassStyle.highlightOpacity : 0.14), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetCountCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("查看剩余重置详情")
    }
}

private struct BankedResetDetailsPopover: View {
    let quota: CodexQuota

    private var sortedResets: [CodexBankedReset] {
        BankedResetPresentation.sortedResets(for: quota)
    }

    private var availableCount: Int {
        quota.bankedResetAvailableCount ?? quota.bankedResets.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("重置次数")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 14)

                Text("可用 \(availableCount) 次")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .frame(height: 23)
                    .background(.white.opacity(0.08), in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            }

            Text("达到限制时可手动使用")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            if sortedResets.isEmpty {
                EmptyBankedResetState(availableCount: availableCount)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(sortedResets.prefix(4).enumerated()), id: \.offset) { index, reset in
                        BankedResetRow(index: index + 1, reset: reset)
                    }

                    if sortedResets.count > 4 {
                        Text("还有 \(sortedResets.count - 4) 次未展开")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                if let earliest = BankedResetPresentation.earliestExpirationLabel(for: quota) {
                    HStack(spacing: 7) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .black))
                        Text(earliest)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 1.00, green: 0.73, blue: 0.20))
                }
            }
        }
        .padding(14)
        .frame(width: 252, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetDetailsCornerRadius, style: .continuous)
                .fill(.clear)
                .background {
                    GlassBackground(cornerRadius: CodexPanelVisualMetrics.resetDetailsCornerRadius)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetDetailsCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.32, blue: 0.33).opacity(0.07),
                                    Color(red: 0.01, green: 0.024, blue: 0.028).opacity(CodexSpatialGlassStyle.panelSmokeOpacity),
                                    .black.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.resetDetailsCornerRadius, style: .continuous)
                        .stroke(.white.opacity(CodexSpatialGlassStyle.highlightOpacity), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.38), radius: 20, y: 12)
    }
}

private struct BankedResetRow: View {
    let index: Int
    let reset: CodexBankedReset

    var body: some View {
        HStack {
            Text("第 \(index) 次")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 12)

            Text("\(expirationLabel) 过期")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var expirationLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: reset.expiresAt)
    }
}

private struct EmptyBankedResetState: View {
    let availableCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            Text(detail)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var title: String {
        if availableCount > 0 {
            return "已读取到 \(availableCount) 次可用重置"
        }
        return "暂无可用重置"
    }

    private var detail: String {
        if availableCount > 0 {
            return "Codex 暂未返回每次过期时间"
        }
        return "达到限制后这里会显示可用重置"
    }
}

private struct PanelGlassShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.outerPanelCornerRadius, style: .continuous)
            .fill(.clear)
            .background {
                GlassBackground(cornerRadius: CodexPanelVisualMetrics.outerPanelCornerRadius)
            }
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.outerPanelCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.32, blue: 0.33).opacity(0.08),
                                Color(red: 0.008, green: 0.020, blue: 0.024).opacity(CodexSpatialGlassStyle.panelSmokeOpacity),
                                .black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.outerPanelCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(CodexSpatialGlassStyle.highlightOpacity),
                                .white.opacity(0.08),
                                .black.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.outerPanelCornerRadius, style: .continuous))
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
        .frame(height: CodexPanelVisualMetrics.statusCardHeight)
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
        RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.statusCardCornerRadius, style: .continuous)
            .fill(Color(red: 0.030, green: 0.046, blue: 0.052).opacity(CodexSpatialGlassStyle.cardSmokeOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.statusCardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.035),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.statusCardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
    }
}

private struct QuotaCardsRow: View {
    let quota: CodexQuota

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(0, proxy.size.width - CodexPanelVisualMetrics.moduleSpacing)
            HStack(spacing: CodexPanelVisualMetrics.moduleSpacing) {
                CombinedQuotaCard(quota: quota)
                .frame(width: availableWidth * 0.60)

                ResetTimingCard(resetAt: quota.weeklyResetAt)
                    .frame(width: availableWidth * 0.40)
            }
        }
    }
}

private struct CombinedQuotaCard: View {
    let quota: CodexQuota

    var body: some View {
        VStack(alignment: .leading, spacing: CodexPanelVisualMetrics.quotaWindowSpacing) {
            Text("额度")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            if quota.fiveHourRemainingPercent != nil {
                QuotaWindowRow(
                    label: "5 小时",
                    remainingPercent: quota.fiveHourRemainingPercent,
                    resetAt: quota.fiveHourResetAt,
                    resetDateFormat: "H:mm"
                )
            }

            QuotaWindowRow(
                label: "1 周",
                remainingPercent: quota.weeklyRemainingPercent,
                resetAt: quota.weeklyResetAt,
                resetDateFormat: "M月d日"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, CodexPanelVisualMetrics.quotaCardVerticalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.quotaCardCornerRadius, style: .continuous)
            .fill(Color(red: 0.030, green: 0.046, blue: 0.052).opacity(CodexSpatialGlassStyle.cardSmokeOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.quotaCardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.03),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.quotaCardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
    }
}

private struct QuotaWindowRow: View {
    let label: String
    let remainingPercent: Double?
    let resetAt: Date?
    let resetDateFormat: String

    private var normalizedRemaining: Double {
        min(100, max(0, remainingPercent ?? 0))
    }

    private var accent: Color {
        switch WeeklyQuotaPresentation.remainingBand(for: remainingPercent) {
        case .ample:
            Color(red: 0.26, green: 0.90, blue: 0.48)
        case .caution:
            Color(red: 1.00, green: 0.73, blue: 0.20)
        case .critical:
            Color(red: 1.00, green: 0.30, blue: 0.28)
        case .unknown:
            .white.opacity(0.36)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer(minLength: 4)

                Text(remainingPercent.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(resetLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .monospacedDigit()
                    .lineLimit(1)
            }

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
                        .frame(width: proxy.size.width * normalizedRemaining / 100)
                        .animation(.easeInOut(duration: 0.32), value: normalizedRemaining)
                }
            }
            .frame(height: CodexPanelVisualMetrics.quotaWindowProgressHeight)
        }
    }

    private var resetLabel: String {
        guard let resetAt else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = resetDateFormat
        return formatter.string(from: resetAt)
    }
}

private struct ResetTimingCard: View {
    let resetAt: Date?
    @State private var currentTime = Date()

    private var elapsedProgress: Double {
        WeeklyQuotaPresentation.cycleElapsedProgress(resetAt: resetAt, now: currentTime) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("下次重置")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))

                Spacer(minLength: 8)

                Text(resetDateLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
            }

            Text(WeeklyQuotaPresentation.resetCountdownLabel(resetAt: resetAt, now: currentTime))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("本周期额度恢复")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule()
                        .fill(.white.opacity(0.34))
                        .frame(width: proxy.size.width * elapsedProgress)
                    Circle()
                        .fill(.white.opacity(0.68))
                        .frame(width: 5, height: 5)
                        .offset(x: max(0, proxy.size.width * elapsedProgress - 5))
                }
                .animation(.easeInOut(duration: 0.32), value: elapsedProgress)
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, CodexPanelVisualMetrics.quotaCardVerticalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardBackground)
        .task {
            while !Task.isCancelled {
                let now = Date()
                currentTime = now
                let nextRefresh = WeeklyQuotaPresentation.nextHourlyRefresh(after: now)
                let waitNanoseconds = UInt64(max(1, nextRefresh.timeIntervalSince(now) * 1_000_000_000))
                try? await Task.sleep(nanoseconds: waitNanoseconds)
            }
        }
    }

    private var resetDateLabel: String {
        guard let resetAt else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: resetAt)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.quotaCardCornerRadius, style: .continuous)
            .fill(Color(red: 0.030, green: 0.046, blue: 0.052).opacity(CodexSpatialGlassStyle.cardSmokeOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.quotaCardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.03),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CodexPanelVisualMetrics.quotaCardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
    }
}
