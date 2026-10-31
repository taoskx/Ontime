import SwiftUI
import AppKit

// MARK: - 时间解析（与 Windows 版 On Time 7 相同规则）
// 支持"时:分:秒" / "分:秒" / "纯秒"，冒号兼容全角，必须 > 0
enum TimeParser {
    static func parse(_ s: String) -> Int? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        t = t.replacingOccurrences(of: "：", with: ":")
        let parts = t.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...3).contains(parts.count) else { return nil }
        var nums: [Int] = []
        for p in parts {
            guard let v = Int(p) else { return nil }
            nums.append(v)
        }
        let total: Int
        switch nums.count {
        case 1: total = nums[0]
        case 2: total = nums[0] * 60 + nums[1]
        default: total = nums[0] * 3600 + nums[1] * 60 + nums[2]
        }
        return total > 0 ? total : nil
    }

    static func hms(_ total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Color <-> RGBA 存取
func rgbaComponents(of color: Color) -> [Double] {
    let c = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    return [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent)]
}

func color(from rgba: [Double]) -> Color? {
    guard rgba.count == 4 else { return nil }
    return Color(red: rgba[0], green: rgba[1], blue: rgba[2], opacity: rgba[3])
}

// MARK: - 设置（UserDefaults 持久化）
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var bgColor: Color {
        didSet { d.set(rgbaComponents(of: bgColor), forKey: "bgColor") }
    }
    @Published var fontColor: Color {
        didSet { d.set(rgbaComponents(of: fontColor), forKey: "fontColor") }
    }
    /// 透明背景：悬浮窗不画背景色，只剩时间文字
    @Published var bgTransparent: Bool {
        didSet { d.set(bgTransparent, forKey: "bgTransparent") }
    }
    /// 文字阴影：时间文字加投影，在浅色幻灯片上也清晰
    @Published var fontShadow: Bool {
        didSet { d.set(fontShadow, forKey: "fontShadow") }
    }
    @Published var fontName: String {
        didSet { d.set(fontName, forKey: "fontName") }
    }
    @Published var fontSize: Double {
        didSet { d.set(fontSize, forKey: "fontSize") }
    }
    @Published var useHMS: Bool {
        didSet { d.set(useHMS, forKey: "useHMS") }
    }
    @Published var timeH: Int {
        didSet { d.set(timeH, forKey: "timeH") }
    }
    @Published var timeM: Int {
        didSet { d.set(timeM, forKey: "timeM") }
    }
    @Published var timeS: Int {
        didSet { d.set(timeS, forKey: "timeS") }
    }

    // 三个框拼出的总秒数
    var totalSeconds: Int { timeH * 3600 + timeM * 60 + timeS }
    @Published var opacity: Double {
        didSet { d.set(opacity, forKey: "opacity") }
    }
    @Published var showTip: Bool {
        didSet { d.set(showTip, forKey: "showTip") }
    }
    @Published var tipText: String {
        didSet { d.set(tipText, forKey: "tipText") }
    }

    var nsFont: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    }

    func setFont(_ f: NSFont) {
        fontName = f.fontName
        fontSize = Double(f.pointSize)
    }

    private init() {
        let defBg = Color(red: 183/255, green: 71/255, blue: 42/255)
        if let a = d.array(forKey: "bgColor") as? [Double], let c = color(from: a) {
            _bgColor = Published(initialValue: c)
        } else {
            _bgColor = Published(initialValue: defBg)
        }
        if let a = d.array(forKey: "fontColor") as? [Double], let c = color(from: a) {
            _fontColor = Published(initialValue: c)
        } else {
            _fontColor = Published(initialValue: .white)
        }
        _bgTransparent = Published(initialValue: d.object(forKey: "bgTransparent") as? Bool ?? false)
        _fontShadow = Published(initialValue: d.object(forKey: "fontShadow") as? Bool ?? false)
        _fontName = Published(initialValue: d.string(forKey: "fontName") ?? "PingFangSC-Semibold")
        _fontSize = Published(initialValue: d.object(forKey: "fontSize") as? Double ?? 28)
        _useHMS = Published(initialValue: d.object(forKey: "useHMS") as? Bool ?? true)
        if d.object(forKey: "timeH") != nil {
            _timeH = Published(initialValue: d.integer(forKey: "timeH"))
            _timeM = Published(initialValue: d.integer(forKey: "timeM"))
            _timeS = Published(initialValue: d.integer(forKey: "timeS"))
        } else if let old = d.string(forKey: "timeText"), let t = TimeParser.parse(old) {
            // 从旧版"时:分:秒"单框迁移过来
            let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
            _timeH = Published(initialValue: h)
            _timeM = Published(initialValue: m)
            _timeS = Published(initialValue: sec)
            d.set(h, forKey: "timeH"); d.set(m, forKey: "timeM"); d.set(sec, forKey: "timeS")
        } else {
            _timeH = Published(initialValue: 0)
            _timeM = Published(initialValue: 0)
            _timeS = Published(initialValue: 0)
        }
        _opacity = Published(initialValue: d.object(forKey: "opacity") as? Double ?? 100)
        _showTip = Published(initialValue: d.object(forKey: "showTip") as? Bool ?? false)
        _tipText = Published(initialValue: d.string(forKey: "tipText") ?? "倒计时结束")
    }

    func reset() {
        bgColor = Color(red: 183/255, green: 71/255, blue: 42/255)
        fontColor = .white
        bgTransparent = false
        fontShadow = false
        fontName = "PingFangSC-Semibold"
        fontSize = 28
        useHMS = true
        timeH = 0; timeM = 0; timeS = 0
        opacity = 100
        showTip = false
        tipText = "倒计时结束"
    }
}

// MARK: - 系统字体面板
class FontPicker: NSObject {
    static let shared = FontPicker()
    private var onPick: ((NSFont) -> Void)?

    @objc func changeFont(_ sender: NSFontManager?) {
        if let f = sender?.selectedFont {
            onPick?(f)
        }
    }

    func show(current: NSFont, onPick: @escaping (NSFont) -> Void) {
        self.onPick = onPick
        let fm = NSFontManager.shared
        fm.target = self
        fm.setSelectedFont(current, isMultiple: false)
        fm.orderFrontFontPanel(nil)
    }
}
