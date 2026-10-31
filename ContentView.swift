import SwiftUI
import AppKit

// MARK: - 设置窗口（On Time 7）
struct ContentView: View {
    @ObservedObject var s = AppSettings.shared
    @ObservedObject private var remote = RemoteControl.shared
    @State private var hourText: String
    @State private var minText: String
    @State private var secText: String

    private let labelW: CGFloat = 64

    private let presets: [(String, Int, Int)] = [
        ("10分钟", 0, 10), ("15分钟", 0, 15), ("20分钟", 0, 20),
        ("30分钟", 0, 30), ("45分钟", 0, 45), ("60分钟", 0, 60)
    ]

    // 快捷配色：背景 + 时间，一点即换（第一套=默认砖红+白）
    private let colorPresets: [(String, Color, Color)] = [
        ("砖红",   Color(red: 183/255, green: 71/255, blue: 42/255),
                  Color.white),
        ("曜石金", Color(red: 28/255, green: 28/255, blue: 30/255),
                  Color(red: 229/255, green: 192/255, blue: 123/255)),
        ("松针绿", Color(red: 30/255, green: 58/255, blue: 47/255),
                  Color(red: 240/255, green: 235/255, blue: 224/255)),
        ("藏青",   Color(red: 35/255, green: 42/255, blue: 59/255),
                  Color(red: 221/255, green: 227/255, blue: 234/255)),
    ]

    init() {
        let st = AppSettings.shared
        _hourText = State(initialValue: st.timeH > 0 ? "\(st.timeH)" : "")
        _minText  = State(initialValue: st.timeM > 0 ? "\(st.timeM)" : "")
        _secText  = State(initialValue: st.timeS > 0 ? "\(st.timeS)" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On Time 7")
                .font(.title)
                .bold()
                .foregroundColor(Color(red: 183/255, green: 71/255, blue: 42/255))

            // ---- 外观 ----
            row("背景颜色") {
                HStack(spacing: 8) {
                    ColorPicker("", selection: $s.bgColor).labelsHidden()
                        .disabled(s.bgTransparent)
                    Toggle("透明背景", isOn: $s.bgTransparent)
                }
            }
            row("时间颜色") {
                HStack(spacing: 8) {
                    ColorPicker("", selection: $s.fontColor).labelsHidden()
                    Button("黑") { s.fontColor = .black }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button("透明") { s.fontColor = .clear }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button(s.fontShadow ? "阴影 ✓" : "阴影") { s.fontShadow.toggle() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            row("快捷配色") {
                HStack(spacing: 10) {
                    ForEach(colorPresets, id: \.0) { p in
                        Button(action: { s.bgColor = p.1; s.fontColor = p.2; s.bgTransparent = false }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(p.1)
                                    .frame(width: 56, height: 32)
                                Text("88")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(p.2)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(p.0)
                    }
                }
            }
            row("字体设置") {
                Button("…") { FontPicker.shared.show(current: s.nsFont) { s.setFont($0) } }
                Text("\(s.fontName)  \(Int(s.fontSize))pt")
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
            row("显示格式") {
                Picker("", selection: $s.useHMS) {
                    Text("时:分:秒").tag(true)
                    Text("秒数").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .labelsHidden()
            }
            row("不透明度") {
                Slider(value: $s.opacity, in: 20...100, step: 1)
                    .frame(width: 200)
                Text("\(Int(s.opacity))%")
                    .frame(width: 46, alignment: .leading)
                    .foregroundColor(.secondary)
            }

            Divider()

            // ---- 时长 ----
            Text("倒计时长")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(presets, id: \.0) { p in
                    Button(p.0) { setPreset(h: p.1, m: p.2) }
                        .buttonStyle(.bordered)
                }
            }
            HStack(spacing: 6) {
                timeBox($hourText, limit: 3)
                Text("时")
                timeBox($minText, limit: 2)
                Text("分")
                timeBox($secText, limit: 2)
                Text("秒")
                Text("只需填数字，不用打冒号")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // ---- 提醒 ----
            row("提示语") {
                Toggle("", isOn: $s.showTip).labelsHidden()
                TextField("倒计时结束", text: $s.tipText)
                    .frame(width: 170)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!s.showTip)
            }

            HStack(spacing: 12) {
                Button("恢复默认设置") {
                    s.reset()
                    hourText = ""; minText = ""; secText = ""
                }
                Spacer()
                Button("数字时钟") { AppDelegate.shared?.openClock() }
                    .controlSize(.large)
                Button("倒计时") { startCountdown() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.top, 4)

            Text("快捷键 ⌃+⌘+H：显示 / 隐藏悬浮窗")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 2)
            Text("手机遥控")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top, spacing: 12) {
                if let img = remote.qrImage {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("手机连同一 WiFi 后扫码")
                        .font(.caption)
                    Text(remote.urlString.isEmpty ? "正在启动服务…" : remote.urlString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    Text("可远程暂停/开始、重置、改时长")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(remote.running ? "● 服务运行中" : "● 服务未启动")
                        .font(.caption2)
                        .foregroundColor(remote.running ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
    }

    // 表单行：标签固定宽度右对齐，保证纵向对齐美观
    @ViewBuilder
    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: labelW, alignment: .trailing)
                .foregroundColor(.secondary)
            content()
        }
    }

    // 数字输入框：只允许数字、限制长度，回车提交
    private func timeBox(_ text: Binding<String>, limit: Int) -> some View {
        TextField("00", text: text)
            .frame(width: 52)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .onChange(of: text.wrappedValue) { _, v in
                let f = String(v.filter { $0.isNumber }.prefix(limit))
                if f != v { text.wrappedValue = f }
            }
            .onSubmit { commitTime() }
    }

    // 提交三个框：空=0，分/秒钳制 0–59，持久化
    private func commitTime() {
        let h = max(0, Int(hourText) ?? 0)
        let m = min(max(0, Int(minText) ?? 0), 59)
        let sec = min(max(0, Int(secText) ?? 0), 59)
        s.timeH = h; s.timeM = m; s.timeS = sec
        hourText = h > 0 ? "\(h)" : ""
        minText  = m > 0 ? "\(m)" : ""
        secText  = sec > 0 ? "\(sec)" : ""
    }

    private func setPreset(h: Int, m: Int) {
        s.timeH = h; s.timeM = m; s.timeS = 0
        hourText = h > 0 ? "\(h)" : ""
        minText  = m > 0 ? "\(m)" : ""
        secText  = ""
    }

    // 点"倒计时"先提交三个框：时长为 0 弹"转换失败"且不打开
    private func startCountdown() {
        commitTime()
        guard s.totalSeconds > 0 else {
            let a = NSAlert()
            a.messageText = "转换失败，请先设置时长（至少 1 秒）。比如小时框填 1、分钟框填 30"
            a.addButton(withTitle: "确定")
            a.runModal()
            return
        }
        AppDelegate.shared?.openCountdown(seconds: s.totalSeconds)
    }
}
