import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard let demo = NSImage(contentsOf: root.appendingPathComponent("demo.png")) else { fatalError("Missing demo.png") }

func render(_ name: String, width: Int, height: Int, title: String, subtitle: String, footer: String) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot create canvas") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let w = CGFloat(width), h = CGFloat(height), s = w / 1600
    NSColor(calibratedRed: 0.035, green: 0.047, blue: 0.052, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: w, height: h).fill()
    NSColor(calibratedRed: 0.15, green: 0.80, blue: 0.48, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 78*s, y: h-96*s, width: 10*s, height: 10*s), xRadius: 5*s, yRadius: 5*s).fill()
    func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight) {
        let style = NSMutableParagraphStyle(); style.lineSpacing = 9*s
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size*s, weight: weight), .foregroundColor: color, .paragraphStyle: style]
        (value as NSString).draw(in: NSRect(x: x*s, y: y*s, width: width*s, height: 230*s), withAttributes: attributes)
    }
    text("CODEX QUOTA", x: 102, y: (h/s)-315, width: 470, size: 18, color: NSColor(calibratedWhite: 0.72, alpha: 1), weight: .semibold)
    text(title, x: 78, y: (h/s)*0.50, width: 550, size: 49, color: .white, weight: .bold)
    text(subtitle, x: 80, y: (h/s)*0.34, width: 500, size: 23, color: NSColor(calibratedWhite: 0.73, alpha: 1), weight: .regular)
    text(footer, x: 80, y: -170, width: 700, size: 16, color: NSColor(calibratedWhite: 0.55, alpha: 1), weight: .medium)
    let imageWidth = 920*s, imageHeight = imageWidth * 712 / 1000
    demo.draw(in: NSRect(x: 615*s, y: (h-imageHeight)/2, width: imageWidth, height: imageHeight), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
    try png.write(to: root.appendingPathComponent(name), options: .atomic)
}

let scenes = [
    ("让 Codex 状态\n一眼可见", "悬浮在桌面上的状态灯与额度面板", "macOS  ·  MIT 开源  ·  画面为演示数据"),
    ("红绿灯，\n随时掌握动态", "查看当前任务状态与最近活动", "状态根据本地 Codex 会话记录推断"),
    ("额度和重置，\n看得更清楚", "按账户实际返回的额度窗口展示", "5 小时额度不存在时显示周额度"),
    ("轻轻悬浮，\n随手拖动", "展开查看详情，离开后自动收起", "画面为实际应用的虚构数据演示"),
    ("Codex Quota", "MIT 开源 · macOS 桌面工具", "github.com/LeeYH95/codex-status-light")
]
for (index, scene) in scenes.enumerated() {
    try render("scene-\(index + 1).png", width: 1600, height: 900, title: scene.0, subtitle: scene.1, footer: scene.2)
}
try render("social-preview.png", width: 1200, height: 630, title: scenes[0].0, subtitle: scenes[0].1, footer: scenes[0].2)
