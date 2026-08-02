import Foundation

public enum CodexSpatialGlassStyle {
    /// The dark tint laid over native material so the panel remains a smoke glass surface.
    public static let panelSmokeOpacity = 0.34

    /// Interior surfaces stay translucent enough to read as layers within the main glass panel.
    public static let cardSmokeOpacity = 0.38

    /// A restrained top-edge reflection keeps the glass crisp without becoming glossy plastic.
    public static let highlightOpacity = 0.12

    /// The dark HUD material supplies the real background blur beneath each outer surface.
    public static let usesNativeMaterial = true

    /// HUD material must render in dark appearance even when macOS is using light appearance.
    public static let forcesDarkAppearance = true

    /// The traffic housing uses one outer contour rather than a stacked pair of edge treatments.
    public static let usesSingleTrafficEdge = true

    /// The reservoir clips both the native glass backing and animated water to its outer shape.
    public static let clipsQuotaReservoirToShape = true
}
