import SwiftUI
import AppKit
import Carbon
import Combine
import ApplicationServices  // 翻页用的 AXIsProcessTrusted（辅助功能权限检测）

@main
struct OnTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("On Time 7") {
            ContentView()
        }
        .windowResizability(.contentSize)  // 锁定窗口尺寸，不可拖拽拉伸
    }
}

// 全局快捷键回调（C 函数指针，不能捕获上下文）
private func hotKeyProc(_ next: EventHandlerCallRef?, _ ev: EventRef?, _ ud: UnsafeMutableRawPointer?) -> OSStatus {
    // 回到主线程操作窗口
    DispatchQueue.main.async {
        AppDelegate.shared?.toggleFloating()
    }
    return noErr
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    // 悬浮窗尺寸：倒计时与数字时钟均为 190 宽
    static let countdownW: CGFloat = 190
    static let clockW: CGFloat = 190
    static let floatH: CGFloat = 64
    var countdownWC: NSWindowController?
    var countdownVM: CountdownVM?
    // 上次拖拽位置：关闭后重开时恢复（同一会话内有效）
    private var lastCountdownOrigin: NSPoint?
    private var lastClockOrigin: NSPoint?
    var clockWC: NSWindowController?
    var hotKeyRef: EventHotKeyRef?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ note: Notification) {
        AppDelegate.shared = self
        // 手机遥控：启动内嵌 HTTP 服务器
        RemoteControl.shared.start()
        // 注册全局快捷键 Control+Command+H（⌃+⌘+H）
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // 注：InstallApplicationEventHandler 是 C 宏，Swift 无法导入；
        // 直接调它展开后的真函数 InstallEventHandler（等价）。
        InstallEventHandler(GetApplicationEventTarget(), hotKeyProc, 1, &spec, nil, nil)
        var ref: EventHotKeyRef?
        let hid = EventHotKeyID(signature: OSType(0x4F4B54), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_H),
                             UInt32(cmdKey | controlKey),
                             hid, GetApplicationEventTarget(), 0, &ref)
        hotKeyRef = ref
        // 透明度滑条实时同步到已打开的悬浮窗（背景/时间颜色经 SwiftUI 已实时同步）
        AppSettings.shared.$opacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                let a = CGFloat(v) / 100.0
                self?.countdownWC?.window?.alphaValue = a
                self?.clockWC?.window?.alphaValue = a
            }
            .store(in: &cancellables)
    }

    // 快捷键：显示/隐藏悬浮窗
    func toggleFloating() {
        let wins = [countdownWC?.window, clockWC?.window].compactMap { $0 }.filter { $0.isVisible }
        if wins.isEmpty {
            countdownWC?.window?.orderFrontRegardless()
            clockWC?.window?.orderFrontRegardless()
        } else {
            wins.forEach { $0.orderOut(nil) }
        }
    }

    // 无边框悬浮面板：NSPanel + nonactivatingPanel（和 Spotlight/Raycast 同类）
    // 普通 NSWindow 在全屏 Space 上会被系统压住/抢焦点导致踢出全屏；
    // nonactivating 面板浮在全屏上时，点击/拖动不抢焦点、不会把用户踢出全屏
    func floatingWindow<V: View>(view: V, width: CGFloat, height: CGFloat) -> NSWindowController {
        let panel = NSPanel(contentRect: NSMakeRect(0, 0, width, height),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // macOS 26 起 isMovableByWindowBackground 对无边框 nonactivating NSPanel 失效，
        // 改下面 WindowDragMove 手势手动搬窗口，这里必须关掉，否则系统拖动和手势拖动会叠加成双倍位移
        panel.isMovableByWindowBackground = false
        // 最高窗口级别 + 全屏辅助：压住一切全屏应用（Keynote/PPT/浏览器全屏）
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentViewController = NSHostingController(rootView: view)
        return NSWindowController(window: panel)
    }

    /// 新悬浮窗定位：有关闭前的位置就恢复，没有才居中
    private func placeWindow(_ wc: NSWindowController, savedOrigin: NSPoint?) {
        if let o = savedOrigin {
            wc.window?.setFrameOrigin(o)
        } else {
            wc.window?.center()
        }
    }

    /// 只刷新外观（不透明度），不碰位置：重启/暂停不能把窗口拽回屏幕中央
    func applyLook(_ win: NSWindow) {
        win.alphaValue = CGFloat(AppSettings.shared.opacity) / 100.0
    }

    // 打开倒计时：已有悬浮窗则按当前设置重计时；设置窗口自动最小化
    func openCountdown(seconds: Int) {
        if let vm = countdownVM, countdownWC?.window?.isVisible == true {
            vm.restartWith(total: seconds)
            if let w = countdownWC?.window { applyLook(w) }
            NSApp.mainWindow?.miniaturize(nil)
            return
        }
        let vm = CountdownVM(total: seconds)
        let wc = floatingWindow(view: CountdownView(vm: vm), width: Self.countdownW, height: Self.floatH)
        vm.onClose = { [weak self] in
            if let w = self?.countdownWC?.window { self?.lastCountdownOrigin = w.frame.origin }
            self?.countdownWC?.close()
            self?.countdownWC = nil
            self?.countdownVM = nil
        }
        placeWindow(wc, savedOrigin: lastCountdownOrigin)
        applyLook(wc.window!)
        wc.showWindow(nil)
        wc.window?.orderFrontRegardless()  // 全屏应用处于前台时也要强制置顶
        countdownWC = wc
        countdownVM = vm
        vm.start()
        NSApp.mainWindow?.miniaturize(nil)
    }

    func openClock() {
        if let w = clockWC?.window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            return
        }
        let vm = ClockVM()
        let wc = floatingWindow(view: ClockView(vm: vm), width: Self.clockW, height: Self.floatH)
        vm.onClose = { [weak self] in
            if let w = self?.clockWC?.window { self?.lastClockOrigin = w.frame.origin }
            self?.clockWC?.close()
            self?.clockWC = nil
        }
        placeWindow(wc, savedOrigin: lastClockOrigin)
        applyLook(wc.window!)
        wc.showWindow(nil)
        wc.window?.orderFrontRegardless()  // 全屏应用处于前台时也要强制置顶
        clockWC = wc
        vm.start()
    }

    // MARK: - 手机遥控（HTTP 服务器在后台线程调用，进来后已切到主线程）
    func remoteState() -> [String: Any] {
        guard let vm = countdownVM, countdownWC?.window?.isVisible == true else {
            return ["hasTimer": false]
        }
        let st = vm.stateInfo
        return ["hasTimer": true,
                "remaining": st.remaining,
                "total": st.total,
                "paused": st.paused,
                "overTime": st.overTime,
                "text": vm.text]
    }

    func remoteCommand(_ cmd: [String: Any]) -> [String: Any] {
        guard let action = cmd["action"] as? String else { return ["ok": false] }
        let visible = countdownWC?.window?.isVisible == true
        switch action {
        case "toggle":
            if visible { countdownVM?.togglePause(); return ["ok": true] }
        case "reset":
            if visible { countdownVM?.restart(); return ["ok": true] }
        case "close":
            countdownVM?.close()
            return ["ok": true]
        case "set":
            if let s = cmd["seconds"] as? Int, s > 0 {
                openCountdownRemote(seconds: s)
                return ["ok": true]
            }
        case "prev":
            remotePage(forward: false)
            return ["ok": true]
        case "next":
            remotePage(forward: true)
            return ["ok": true]
        default:
            break
        }
        return ["ok": false]
    }

    /// 手机遥控翻页：模拟 ←/→ 方向键，PowerPoint/Keynote/WPS/浏览器幻灯片通用。
    /// 按键走前台应用——演讲时幻灯片在前台，咱们的面板不抢焦点，正好。
    /// 需要"辅助功能"权限：没给过就弹系统授权框，用户去"系统设置→隐私与安全性→辅助功能"勾选一次即可。
    /// 注意 ad-hoc 签名每次构建 cdhash 都变，每次更新版本后需重新勾选一次。
    func remotePage(forward: Bool) {
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            return
        }
        let key: CGKeyCode = forward ? 0x7C : 0x7B  // → / ←
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)?.post(tap: .cghidEventTap)
    }

    /// 远程开倒计时：不碰设置窗口（远程时设置窗可能最小化着）
    private func openCountdownRemote(seconds: Int) {
        if let vm = countdownVM, countdownWC?.window?.isVisible == true {
            vm.restartWith(total: seconds)
            if let w = countdownWC?.window { applyLook(w) }
            return
        }
        let vm = CountdownVM(total: seconds)
        let wc = floatingWindow(view: CountdownView(vm: vm), width: Self.countdownW, height: Self.floatH)
        vm.onClose = { [weak self] in
            if let w = self?.countdownWC?.window { self?.lastCountdownOrigin = w.frame.origin }
            self?.countdownWC?.close()
            self?.countdownWC = nil
            self?.countdownVM = nil
        }
        placeWindow(wc, savedOrigin: lastCountdownOrigin)
        applyLook(wc.window!)
        wc.showWindow(nil)
        wc.window?.orderFrontRegardless()
        countdownWC = wc
        countdownVM = vm
        vm.start()
    }
}

// MARK: - 悬浮窗手动拖动（各 macOS 版本行为一致，不依赖 isMovableByWindowBackground）
/// 抓取 SwiftUI 视图所在的 NSWindow
struct WindowHandle: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { [weak v] in onWindow(v?.window) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// 按住拖动搬窗口；轻点（位移 < 3pt）不触发拖动，原有的 onTapGesture 照常工作
/// 注意：位移必须用屏幕坐标（NSEvent.mouseLocation）算增量——
/// 若用视图本地坐标的 translation，窗口一动、视图跟着动，位移会被吃回去，
/// 导致窗口来回抽动（不跟手 + 闪烁）
struct WindowDragMove: ViewModifier {
    @State private var win: NSWindow?
    @State private var startMouse: NSPoint?
    @State private var startOrigin: NSPoint?

    func body(content: Content) -> some View {
        content
            .background(WindowHandle { win = $0 })
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { _ in
                        guard let w = win else { return }
                        // 屏幕坐标系（y 向上）与 window.frame 同系，增量直接套用，不用翻转
                        let cur = NSEvent.mouseLocation
                        if startMouse == nil {
                            startMouse = cur
                            startOrigin = w.frame.origin
                        }
                        w.setFrameOrigin(NSPoint(
                            x: startOrigin!.x + cur.x - startMouse!.x,
                            y: startOrigin!.y + cur.y - startMouse!.y))
                    }
                    .onEnded { _ in
                        startMouse = nil
                        startOrigin = nil
                    }
            )
    }
}
