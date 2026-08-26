import Foundation

public enum CodexPanelVisualMetrics {
    public static let panelContentInset = 8.0
    public static let moduleSpacing = 8.0
    public static let headerHeight = 50.0
    public static let dividerHeight = 1.0
    public static let statusCardHeight = 70.0
    public static let quotaCardRowHeight = 96.0
    public static let quotaCardVerticalInset = 12.0
    public static let quotaWindowSpacing = 4.0
    public static let quotaWindowProgressHeight = 5.0
    public static let expandedPanelHeight = headerHeight
        + dividerHeight
        + (panelContentInset * 2)
        + statusCardHeight
        + moduleSpacing
        + quotaCardRowHeight
    public static let statusCardCornerRadius = 16.0
    public static let quotaCardCornerRadius = 14.0
    public static let outerPanelCornerRadius = quotaCardCornerRadius
    public static let resetCountCornerRadius = 12.0
    public static let resetDetailsCornerRadius = 16.0
    public static let quotaGaugeDiameter = 63.0
    public static let quotaGaugeSpacing = 14.0
    public static let quotaReservoirSize = 46.0
    public static let quotaReservoirCornerRadius = 16.0
    public static let trafficLightWithReservoirHeight = 280.0
}
