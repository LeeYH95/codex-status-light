import AppKit
import SwiftUI

struct FloatingWindowConfigurator: NSViewRepresentable {
    var width: CGFloat
    var height: CGFloat

    final class Coordinator: @unchecked Sendable {
        var appliedSize: NSSize?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else {
            return
        }

        let targetSize = NSSize(width: width, height: height)
        if coordinator.appliedSize.map({ !Self.sizesAreClose($0, targetSize) }) ?? true {
            resize(window: window, to: targetSize, coordinator: coordinator)
            coordinator.appliedSize = targetSize
        } else {
            Self.lock(window: window, to: targetSize)
        }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    nonisolated private static func sizesAreClose(_ lhs: NSSize, _ rhs: NSSize) -> Bool {
        abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
    }

    private func resize(window: NSWindow, to contentSize: NSSize, coordinator: Coordinator) {
        let currentFrame = window.frame
        var targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        targetFrame.origin.x = currentFrame.minX
        targetFrame.origin.y = currentFrame.maxY - targetFrame.height

        window.contentMinSize = NSSize(width: 1, height: 1)
        window.contentMaxSize = NSSize(width: 10_000, height: 10_000)
        window.setFrame(targetFrame, display: true, animate: false)
        Self.lock(window: window, to: contentSize)
    }

    private static func lock(window: NSWindow, to contentSize: NSSize) {
        window.contentMinSize = contentSize
        window.contentMaxSize = contentSize
    }
}
