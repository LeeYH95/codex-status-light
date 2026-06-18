import Foundation

public enum TrafficLamp: Equatable, Sendable {
    case red
    case yellow
    case green
}

public struct StatusPresentation: Equatable, Sendable {
    public var activeLamp: TrafficLamp?
    public var isBlinking: Bool
    public var compactLabel: String

    public init(activeLamp: TrafficLamp?, isBlinking: Bool = false, compactLabel: String) {
        self.activeLamp = activeLamp
        self.isBlinking = isBlinking
        self.compactLabel = compactLabel
    }

    public static func presentation(for state: CodexState) -> StatusPresentation {
        switch state {
        case .idle:
            StatusPresentation(activeLamp: .green, compactLabel: "空闲")
        case .thinking:
            StatusPresentation(activeLamp: .yellow, compactLabel: "思考中")
        case .running:
            StatusPresentation(activeLamp: .red, compactLabel: "执行中")
        case .processing:
            StatusPresentation(activeLamp: .red, compactLabel: "处理中")
        case .waiting:
            StatusPresentation(activeLamp: .yellow, compactLabel: "待确认")
        case .done:
            StatusPresentation(activeLamp: .green, compactLabel: "已完成")
        case .failed:
            StatusPresentation(activeLamp: .red, isBlinking: true, compactLabel: "失败")
        case .stalled:
            StatusPresentation(activeLamp: .red, isBlinking: true, compactLabel: "停滞")
        case .unknown:
            StatusPresentation(activeLamp: nil, compactLabel: "未知")
        }
    }

    public static func freshnessLabel(updatedAt: Date?, now: Date = Date()) -> String {
        guard let updatedAt else {
            return "监听中"
        }

        let elapsedSeconds = max(0, Int(now.timeIntervalSince(updatedAt)))
        if elapsedSeconds < 60 {
            return "刚刚"
        }

        let elapsedMinutes = elapsedSeconds / 60
        if elapsedMinutes < 60 {
            return "\(elapsedMinutes)分钟前"
        }

        let elapsedHours = elapsedMinutes / 60
        if elapsedHours < 24 {
            return "\(elapsedHours)小时前"
        }

        return "1天前"
    }
}
