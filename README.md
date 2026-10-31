On Time 7 - Mac 原生版（Swift/SwiftUI，Apple M 芯片）
================================================
这是一个真正的 Mac 原生小程序，编出来只有 2~3MB。
功能与 Windows 版 On Time 7 完全一致：
设置（背景色/时间色/字体/格式/时间/透明度/提示语/恢复默认）、
倒计时（点开始先提交时间、超时正计时+0.8秒闪、点一下暂停/继续、
暂停时顶部显示带阴影的 ▶、右键菜单：重新开始/切换格式/结束前提醒/关闭）、
数字时钟、全局快捷键 ⌃+⌘+H 显示/隐藏悬浮窗。

（在你的 Mac 上操作，约 5 分钟）

1. 装 Xcode（免费）
打开 App Store，搜索 "Xcode"，点"获取"安装。
第一次打开 Xcode，它会提示安装附加组件，点"安装"同意。

2. 新建项目
Xcode 菜单：File → New → Project…
选 macOS → App → Next。
Product Name 填：OnTime
Interface 选：SwiftUI
Language 选：Swift
下面 Storage / Tests 都不要勾 → Next。
保存位置选"桌面" → Create。

3. 替换两个默认文件的内容
左侧项目导航里点开 OnTime 文件夹：
① 点 OnTimeApp.swift → 全选（⌘A）删掉 → 把本包里的 OnTimeApp.swift
内容全选复制粘贴进去。
② 点 ContentView.swift → 全选删掉 → 把本包里的 ContentView.swift
内容全选复制粘贴进去。

4. 加入另外四个文件
把本包里的 Models.swift、CountdownView.swift、ClockView.swift、
RemoteServer.swift 四个文件，直接拖到 Xcode 左侧的 OnTime 文件夹里。
弹出的框里勾选 "Copy items if needed"，下面 Target 勾选 OnTime → Finish。

5. 运行
按 ⌘R（或点左上角 ▶ 按钮），设置窗口出来就成功了。
点"倒计时"试试：悬浮窗出现、可以拖、点一下暂停（顶部出 ▶）、
右键有菜单。Mac 会要"辅助功能"之类的权限？这个版本不需要，
快捷键用的是系统级热键，无需额外授权。

6. 生成独立的 App（可选）
菜单 Product → Archive… → 等待完成 → Distribute App → Copy App
→ Next → 导出，得到 OnTime.app，拖进"应用程序"文件夹即可。
（未签名：第一次打开时在 Finder 里右键 OnTime.app → 打开 →
点"打开"，以后双击就行。）


- 只要 M 系列芯片的 Mac（M1/M2/M3/M4），本源码只按 arm64 写。
- 代码是在 Linux 上写的，没经过真机编译。如果 Xcode 报红字错误，
把报错原文（点红叉能看到）发回来，这边改好再发你。
- 文件清单：Models.swift（设置/时间解析/字体面板）、
OnTimeApp.swift（程序入口/悬浮窗/全局快捷键/手动拖动）、
ContentView.swift（设置界面）、CountdownView.swift（倒计时）、
ClockView.swift（数字时钟）、RemoteServer.swift（手机扫码遥控）。
