import SwiftUI
import AppKit

// MARK: - 倒计时逻辑
class CountdownVM: ObservableObject {
    @Published var text: String = ""
    @Published var paused: Bool = false
    @Published var blinkOn: Bool = true
    @Published var remindInput: String = ""
    var onClose: (() -> Void)?

    private var total: Int
    private var remaining: Int
    private var endDate: Date?
    private var timer: Timer?
    private var blinkTimer: Timer?
    private var overTime = false
    private var overSeconds = 0
    private var finishDate = Date()
    private var useHMS: Bool
    private var remindMinutes: [Int] = []
    private var reminded = false
    private let settings = AppSettings.shared

    init(total: Int) {
        self.total = total
        self.remaining = total
        self.useHMS = AppSettings.shared.useHMS
        self.text = useHMS ? TimeParser.hms(total) : "\(total)"
    }

    func start() {
        stopTimers()
        overTime = false
        overSeconds = 0
        paused = false
        reminded = false
        remaining = total
        endDate = Date().addingTimeInterval(TimeInterval(total))
        updateText()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
    }

    // 重新开始：复位后停住，点一下再走（与 Windows 版一致）
    func restart() {
        stopTimers()
        overTime = false
        overSeconds = 0
        remaining = total
        endDate = nil
        reminded = false
        blinkOn = true
        updateText()
        setPaused(true)
    }

    // 按新时长重开并直接开始（设置窗口点"倒计时"时用）
    func restartWith(total: Int) {
        self.total = total
        start()
    }

    func togglePause() { setPaused(!paused) }

    /// 手机遥控用：当前状态快照（主线程调用）
    var stateInfo: (remaining: Int, total: Int, paused: Bool, overTime: Bool) {
        (remaining, total, paused, overTime)
    }

    private func setPaused(_ p: Bool) {
        if p == paused { return }
        if p {
            if let e = endDate {
                remaining = max(0, Int(e.timeIntervalSinceNow.rounded()))
            }
            if overTime {
                overSeconds = max(0, Int(Date().timeIntervalSince(finishDate).rounded()))
            }
            timer?.invalidate()
            timer = nil
        } else {
            if overTime {
                finishDate = Date().addingTimeInterval(TimeInterval(-overSeconds))
            } else {
                endDate = Date().addingTimeInterval(TimeInterval(remaining))
            }
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        }
        paused = p
    }

    private func tick() {
        if overTime {
            overSeconds = max(0, Int(Date().timeIntervalSince(finishDate).rounded()))
            updateText()
            return
        }
        guard let e = endDate else { return }
        let r = Int(e.timeIntervalSinceNow.rounded())
        if r <= 0 {
            finish()
            return
        }
        remaining = r
        if !reminded {
            for m in remindMinutes where r <= m * 60 {
                reminded = true
                showAlert("距离结束还有 \(m) 分钟")
                break
            }
        }
        updateText()
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        overTime = true
        overSeconds = 0
        finishDate = Date()
        text = useHMS ? "00:00:00" : "0"
        if settings.showTip {
            showAlert(settings.tipText)
        }
        // 超时后正向计时，0.8 秒闪一次
        blinkOn = true
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.blinkOn.toggle()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func updateText() {
        if overTime {
            text = useHMS ? TimeParser.hms(overSeconds) : "\(overSeconds)"
        } else {
            text = useHMS ? TimeParser.hms(remaining) : "\(remaining)"
        }
    }

    func toggleFormat() {
        useHMS.toggle()
        updateText()
    }

    func applyRemind() {
        let parts = remindInput.split { $0 == " " || $0 == "," || $0 == "，" }
        remindMinutes = parts.compactMap { Int($0) }.filter { $0 > 0 }
        reminded = false
    }

    func close() {
        stopTimers()
        onClose?()
    }

    private func stopTimers() {
        timer?.invalidate(); timer = nil
        blinkTimer?.invalidate(); blinkTimer = nil
    }

    private func showAlert(_ msg: String) {
        let a = NSAlert()
        a.messageText = msg
        a.addButton(withTitle: "确定")
        a.runModal()
    }
}

// MARK: - 倒计时悬浮窗
struct CountdownView: View {
    @ObservedObject var vm: CountdownVM
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ZStack {
            if !settings.bgTransparent {
                settings.bgColor
            }
            Text(vm.text)
                .font(Font(settings.nsFont))
                .foregroundColor(settings.fontColor)
                .opacity(vm.blinkOn ? 1 : 0)
                .shadow(color: settings.fontShadow ? .black.opacity(0.6) : .clear,
                        radius: 5, x: 0, y: 2)
            // 暂停时：▶ 浮于文字上方，带阴影
            if vm.paused {
                Text("▶")
                    .font(.system(size: 18))
                    .foregroundColor(settings.fontColor)
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 2, y: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 2)
            }
        }
        .frame(width: AppDelegate.countdownW, height: AppDelegate.floatH)
        .modifier(WindowDragMove())  // 按住拖动；轻点仍为暂停/继续
        .onTapGesture { vm.togglePause() }
        .contextMenu {
            Button("重新开始") { vm.restart() }
            Button("切换格式") { vm.toggleFormat() }
            Menu("结束前提醒") {
                TextField("分钟，空格分隔", text: $vm.remindInput)
                    .frame(width: 140)
                Button("确定") { vm.applyRemind() }
            }
            Divider()
            Button("关闭") { vm.close() }
        }
    }
}
