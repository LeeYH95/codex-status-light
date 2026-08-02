import AppKit
import SwiftUI
import CodexTrafficGlassCore

struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 24
    var forcesDarkAppearance = CodexSpatialGlassStyle.forcesDarkAppearance

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = forcesDarkAppearance ? NSAppearance(named: .darkAqua) : nil
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.appearance = forcesDarkAppearance ? NSAppearance(named: .darkAqua) : nil
        nsView.layer?.cornerRadius = cornerRadius
    }
}
