import AppKit
import SwiftUI

/// Moves the HUD directly rather than relying on hosting-view background dragging.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        private var initialWindowOrigin: NSPoint?
        private var initialMouseLocation: NSPoint?

        override var mouseDownCanMoveWindow: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            initialWindowOrigin = window.frame.origin
            initialMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let initialWindowOrigin, let initialMouseLocation else { return }
            let mouseLocation = window.convertPoint(toScreen: event.locationInWindow)
            window.setFrameOrigin(NSPoint(
                x: initialWindowOrigin.x + mouseLocation.x - initialMouseLocation.x,
                y: initialWindowOrigin.y + mouseLocation.y - initialMouseLocation.y
            ))
        }

        override func mouseUp(with event: NSEvent) {
            initialWindowOrigin = nil
            initialMouseLocation = nil
        }
    }
}
