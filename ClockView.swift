import SwiftUI
import AppKit

// MARK: - 数字时钟逻辑
class ClockVM: ObservableObject {
    @Published var text = ""
    @Published var use24h = true
    var onClose: (() -> Void)?

    private var timer: Timer?
    private let f24: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    private let f12: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm:ss a"
        return f
    }()

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
    }

    func tick() {
        text = (use24h ? f24 : f12).string(from: Date())
    }

    func toggleFormat() {
        use24h.toggle()
        tick()
    }

    func close() {
        timer?.invalidate()
        timer = nil
        onClose?()
    }
}

// MARK: - 数字时钟悬浮窗
struct ClockView: View {
    @ObservedObject var vm: ClockVM
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ZStack {
            if !settings.bgTransparent {
                settings.bgColor
            }
            Text(vm.text)
                .font(Font(settings.nsFont))
                .foregroundColor(settings.fontColor)
                .shadow(color: settings.fontShadow ? .black.opacity(0.6) : .clear,
                        radius: 5, x: 0, y: 2)
        }
        .frame(width: AppDelegate.clockW, height: AppDelegate.floatH)
        .modifier(WindowDragMove())  // 按住拖动
        .contextMenu {
            Button("切换格式") { vm.toggleFormat() }
            Divider()
            Button("关闭") { vm.close() }
        }
    }
}
