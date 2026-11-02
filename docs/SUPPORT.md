# On time 演讲者助手 · 技术支持 / Support

On time 是面向会议、培训和演讲的 Mac 悬浮计时工具。当前版本的手机翻页支持 PowerPoint 和 Keynote，不支持 WPS。

## 开始使用

1. 在 Mac 中设置倒计时时长，点击“倒计时”。可暂停、继续或重置；结束后继续显示超时时长并闪烁提醒。
2. 悬浮计时器可显示在 PowerPoint、Keynote 的全屏放映画面之上。可拖动位置，并调节字体、配色、透明背景、不透明度与显示大小。
3. 如需手机遥控，让手机和 Mac 连接同一可信 Wi-Fi，在 Mac 中开启遥控，再用手机扫描当前二维码。无需安装手机 App。
4. 如需翻页，在 Mac 上启动 PowerPoint 或 Keynote 放映；首次发送翻页指令时，在 Mac 上允许相应自动化请求。

## 常见问题

- **二维码打不开 / 连接失败：** 确认遥控已开启、Mac 未睡眠，两台设备在同一可互通局域网。访客 Wi-Fi、设备隔离或防火墙可能阻止连接。
- **链接失效或 403：** 遥控重启后旧链接可能失效，请关闭旧手机页面并扫描 Mac 当前显示的二维码。
- **能计时但不能翻页：** 确认 PowerPoint 或 Keynote 正在放映，在 Mac 系统设置 → 隐私与安全性 → 自动化中检查授权；同时运行两款软件时，请在应用中选择目标软件。
- **最后一页不再前进：** 当前版本会保护最后一页，避免意外退出放映；最后一页的后续点击动画和 PowerPoint 自定义放映暂不支持。
- **安全使用：** 遥控采用局域网 HTTP，请仅在可信网络使用，不要公开二维码。不使用时关闭遥控。

需要 macOS 14 或更高版本。PowerPoint、Keynote 需另行安装。

## 反馈

请在 [GitHub Issues](https://github.com/taoskx/Ontime/issues) 提交问题，注明 macOS 版本、应用版本、演示软件及可复现步骤。该页面公开可见，请勿上传私人演示文档、二维码链接或密码。

[隐私政策](PRIVACY.md)

## English

On time Presenter Assistant is a floating timer for meetings, training and presentations on macOS 14 or later.

Set a duration on the Mac and start the timer. You can pause, resume and reset it. After zero, overtime continues with a flashing reminder. The timer can remain above PowerPoint and Keynote slideshow pages; adjust its position, colors, opacity, transparent background and display size in settings.

For phone control, connect your phone and Mac to the same trusted Wi-Fi, enable remote control on the Mac and scan its current QR code. No phone app is required. To control slides, start a PowerPoint or Keynote slideshow on the Mac and allow macOS Automation access when prompted. WPS is not supported.

If the link expires or reports 403, scan a new QR code. If connection fails, check Mac sleep, network isolation and firewall settings. If slide control fails, check the active slideshow and Automation permission. Select the target presentation app when both are running. Final-slide protection prevents leaving the show; further click animations on the final slide and PowerPoint custom shows are not currently supported.

Remote traffic uses local HTTP, so use only trusted networks and keep QR links private. Report issues through [GitHub Issues](https://github.com/taoskx/Ontime/issues), including app/macOS/presentation-software versions and reproduction steps. Do not post private files, QR tokens or passwords. Read the [privacy policy](PRIVACY.md).
