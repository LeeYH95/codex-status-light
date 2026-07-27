import SwiftUI
import CodexTrafficGlassCore

@main
struct CodexTrafficGlassApp: App {
    @StateObject private var store = CodexStatusStore()

    var body: some Scene {
        WindowGroup {
            TrafficGlassRootView(store: store)
                .background(
                    FloatingWindowConfigurator(
                        width: store.isExpanded ? CodexPanelMotion.expandedWidth : CodexPanelMotion.collapsedWidth,
                        height: CodexPanelMotion.quotaReservoirWindowHeight
                    )
                )
                .onAppear {
                    store.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
