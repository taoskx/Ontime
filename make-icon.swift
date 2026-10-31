import AppKit
import Foundation

// 在云机器上直接绘制应用图标，生成 OnTime.iconset/
// 用法：swift make-icon.swift
// （仓库里不存 PNG：推送工具对二进制文件只会原样存文本，sips 读不了）
//
// 设计：1024 全幅铺满，macOS 会自动套圆角矩形（squircle）遮罩——
// 所以背景必须画满整张、不要自己画圆角，主体放在中央 80% 安全区内。

func drawIcon() -> NSImage {
    let S: CGFloat = 1024
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    // 翻转成左上原点，和设计坐标一致
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)

    // ---- 背景：对角四段渐变（靛蓝 → 紫 → 品红 → 暖橙），色彩丰富
    let bg = NSGradient(colors: [
        NSColor(red: 0.20, green: 0.18, blue: 0.83, alpha: 1.0),  // 靛蓝
        NSColor(red: 0.52, green: 0.24, blue: 0.96, alpha: 1.0),  // 紫
        NSColor(red: 0.93, green: 0.30, blue: 0.58, alpha: 1.0),  // 品红
        NSColor(red: 1.00, green: 0.55, blue: 0.32, alpha: 1.0),  // 暖橙
    ], atLocations: [0.0, 0.38, 0.72, 1.0], colorSpace: .deviceRGB)!
    bg.draw(from: NSPoint(x: 0, y: 0), to: NSPoint(x: S, y: S), options: [])

    // ---- 顶部玻璃高光
    let gloss = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.30),
        NSColor(white: 1.0, alpha: 0.0),
    ], atLocations: [0.0, 1.0], colorSpace: .deviceRGB)!
    gloss.draw(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 0, y: S * 0.55), options: [])

    // ---- 表盘后的径向柔光
    let glow = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.22),
        NSColor(white: 1.0, alpha: 0.0),
    ], atLocations: [0.0, 1.0], colorSpace: .deviceRGB)!
    glow.draw(in: NSRect(x: 512 - 420, y: 560 - 420, width: 840, height: 840),
              relativeCenterPosition: NSPoint(x: 0, y: 0))

    let white = NSColor(white: 1.0, alpha: 1.0)
    let whiteSoft = NSColor(white: 1.0, alpha: 0.88)
    let cx: CGFloat = 512, cy: CGFloat = 570, R: CGFloat = 295

    // ---- 秒表主体投影（翻转坐标系里 y 向下为正，投影落在视觉下方）
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 26), blur: 70,
                  color: NSColor(white: 0, alpha: 0.38).cgColor)

    white.setFill()
    white.setStroke()

    // 表盘外圈
    let ring = NSBezierPath(ovalIn: NSRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
    ring.lineWidth = 66
    ring.stroke()

    // 表冠顶钮 + 柄
    NSBezierPath(roundedRect: NSRect(x: 452, y: 108, width: 120, height: 58), xRadius: 20, yRadius: 20).fill()
    NSBezierPath(rect: NSRect(x: 482, y: 162, width: 60, height: 105)).fill()

    // 侧钮（45°方向）
    let a = -Double.pi / 4
    let ex = cx + (R - 10) * CGFloat(cos(a)), ey = cy + (R - 10) * CGFloat(sin(a))
    let bx = cx + (R + 105) * CGFloat(cos(a)), by = cy + (R + 105) * CGFloat(sin(a))
    let stem = NSBezierPath()
    stem.move(to: CGPoint(x: ex, y: ey))
    stem.line(to: CGPoint(x: bx, y: by))
    stem.lineWidth = 42
    stem.lineCapStyle = .round
    stem.stroke()
    NSBezierPath(ovalIn: NSRect(x: bx - 34, y: by - 34, width: 68, height: 68)).fill()

    // 刻度 12 格
    for i in 0..<12 {
        let t = Double(i) * Double.pi / 6 - Double.pi / 2
        let tick = NSBezierPath()
        tick.move(to: CGPoint(x: cx + 232 * CGFloat(cos(t)), y: cy + 232 * CGFloat(sin(t))))
        tick.line(to: CGPoint(x: cx + 258 * CGFloat(cos(t)), y: cy + 258 * CGFloat(sin(t))))
        tick.lineWidth = 17
        tick.lineCapStyle = .butt
        tick.stroke()
    }

    // 指针：分针指 12，时针指 7（呼应 On Time 7）
    let mh = NSBezierPath()
    mh.move(to: CGPoint(x: cx, y: cy))
    mh.line(to: CGPoint(x: cx, y: cy - 198))
    mh.lineWidth = 36
    mh.lineCapStyle = .round
    mh.stroke()
    let ha = Double(7) * Double.pi / 6  // 7 点方向
    let hx = cx + 138 * CGFloat(sin(ha)), hy = cy - 138 * CGFloat(cos(ha))
    let hh = NSBezierPath()
    hh.move(to: CGPoint(x: cx, y: cy))
    hh.line(to: CGPoint(x: hx, y: hy))
    hh.lineWidth = 40
    hh.lineCapStyle = .round
    hh.stroke()
    // 轴心：白色圆点 + 暖橙点缀
    NSBezierPath(ovalIn: NSRect(x: cx - 34, y: cy - 34, width: 68, height: 68)).fill()
    NSColor(red: 1.0, green: 0.55, blue: 0.30, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - 15, y: cy - 15, width: 30, height: 30)).fill()

    ctx.restoreGState()

    // ---- 表盘内圈细线点缀（投影之外，更 crisp）
    whiteSoft.setStroke()
    let inner = NSBezierPath(ovalIn: NSRect(x: cx - R + 78, y: cy - R + 78,
                                            width: (R - 78) * 2, height: (R - 78) * 2))
    inner.lineWidth = 6
    inner.stroke()

    img.unlockFocus()
    return img
}

let base = drawIcon()
let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]
let fm = FileManager.default
try? fm.createDirectory(atPath: "OnTime.iconset", withIntermediateDirectories: true)
for (px, name) in sizes {
    let small = NSImage(size: NSSize(width: px, height: px))
    small.lockFocus()
    base.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
              from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
              operation: .copy, fraction: 1.0)
    small.unlockFocus()
    if let tiff = small.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "OnTime.iconset/\(name).png"))
    }
}
print("iconset done")
