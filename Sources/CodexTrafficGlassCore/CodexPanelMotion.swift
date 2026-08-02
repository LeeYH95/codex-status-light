import Foundation

public enum CodexPanelDismissalMode: Sendable {
    case hoverOnly
}

public enum CodexPanelMotion {
    public static let duration = 0.24
    public static let revealOffsetX = -14.0
    public static let collapsedScale = 0.985
    public static let hoverCollapseDelay = 0.12
    public static let dismissalMode = CodexPanelDismissalMode.hoverOnly
    public static let expandedWidth = 500.0
    public static let collapsedWidth = 126.0
    public static let expandedPanelHeight = CodexPanelVisualMetrics.expandedPanelHeight
    public static let windowHeight = 276.0
    public static let collapsedWindowHeight = 328.0
    public static let quotaReservoirWindowHeight = collapsedWindowHeight
}
