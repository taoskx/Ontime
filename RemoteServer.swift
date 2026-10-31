import Foundation
import AppKit
import Darwin
import CoreImage

// MARK: - 手机遥控：Mac 内嵌极简 HTTP 服务器（无第三方依赖）
// 设置界面显示二维码，手机连同一 WiFi 扫码后打开远程控制页，
// 可远程暂停/开始、重置、改时长。电脑全屏时不受影响。

// ---------- 极简 HTTP/1.1 服务器（POSIX socket，一次一连接） ----------
final class MiniHTTPServer {
    // method, path, query, body -> (status, contentType, body)
    var handler: ((String, String, [String: String], String) -> (Int, String, String))?

    private var fd: Int32 = -1
    private var running = false
    private(set) var port: Int = 0

    /// 从 startPort 开始尝试绑定，返回实际端口，失败返回 nil
    func start(port startPort: Int) -> Int? {
        for p in startPort..<(startPort + 20) {
            let f = socket(AF_INET, SOCK_STREAM, 0)
            guard f >= 0 else { continue }
            var opt: Int32 = 1
            setsockopt(f, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(p).bigEndian
            addr.sin_addr = in_addr(s_addr: in_addr_t(0).bigEndian) // INADDR_ANY：监听所有网卡，手机才能连
            let ok = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(f, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                        && listen(f, 32) == 0
                }
            }
            guard ok else { close(f); continue }
            self.fd = f
            self.port = p
            self.running = true
            DispatchQueue.global(qos: .utility).async { [weak self] in self?.acceptLoop() }
            return p
        }
        return nil
    }

    func stop() {
        running = false
        if fd >= 0 { close(fd); fd = -1 }
    }

    private func acceptLoop() {
        while running {
            var sa = sockaddr()
            var len = socklen_t(MemoryLayout<sockaddr>.size)
            let c = accept(fd, &sa, &len)
            if c < 0 {
                if running { usleep(50_000) }
                continue
            }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handle(c)
                close(c)
            }
        }
    }

    private func handle(_ c: Int32) {
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 8192)
        var headerEnd: Int? = nil
        while headerEnd == nil {
            let n = recv(c, &buf, buf.count, 0)
            if n <= 0 { return }
            data.append(contentsOf: buf[0..<n])
            if data.count > 131072 { return }
            if let r = data.range(of: Data("\r\n\r\n".utf8)) { headerEnd = r.upperBound }
        }
        let he = headerEnd!
        guard let headerText = String(data: data[0..<he], encoding: .utf8) else { return }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let reqLine = lines.first else { return }
        let parts = reqLine.components(separatedBy: " ")
        guard parts.count >= 3 else { return }
        let method = parts[0]
        let rawPath = parts[1]
        var headers: [String: String] = [:]
        for l in lines.dropFirst() {
            guard let i = l.firstIndex(of: ":") else { continue }
            let k = l[..<i].trimmingCharacters(in: .whitespaces).lowercased()
            headers[k] = l[l.index(after: i)...].trimmingCharacters(in: .whitespaces)
        }
        if method == "POST", let cl = headers["content-length"], let need = Int(cl), need > 0 {
            while data.count - he < need {
                let n = recv(c, &buf, buf.count, 0)
                if n <= 0 { break }
                data.append(contentsOf: buf[0..<n])
                if data.count > 1_048_576 { return }
            }
        }
        let body = data.count > he ? (String(data: data[he...], encoding: .utf8) ?? "") : ""
        let pq = rawPath.components(separatedBy: "?")
        let path = pq[0].removingPercentEncoding ?? pq[0]
        var query: [String: String] = [:]
        if pq.count > 1 {
            for kv in pq[1].components(separatedBy: "&") {
                let a = kv.components(separatedBy: "=")
                if a.count == 2 { query[a[0]] = a[1].removingPercentEncoding ?? a[1] }
            }
        }
        let (status, ctype, respBody) = handler?(method, path, query, body)
            ?? (404, "text/plain; charset=utf-8", "Not Found")
        let respData = respBody.data(using: .utf8) ?? Data()
        let head = "HTTP/1.1 \(status) \(statusText(status))\r\n"
            + "Content-Type: \(ctype)\r\n"
            + "Content-Length: \(respData.count)\r\n"
            + "Connection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(respData)
        out.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            var sent = 0
            while sent < out.count {
                let n = send(c, ptr.baseAddress!.advanced(by: sent), out.count - sent, 0)
                if n <= 0 { break }
                sent += n
            }
        }
    }

    private func statusText(_ s: Int) -> String {
        switch s {
        case 200: return "OK"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        default: return "Error"
        }
    }
}

// ---------- 本机局域网 IP ----------
func localIPAddress() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    defer { freeifaddrs(ifaddr) }
    var ptr = ifaddr
    var fallback: String?
    while let p = ptr {
        let ifa = p.pointee
        let name = String(cString: ifa.ifa_name)
        if ifa.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let len = socklen_t(ifa.ifa_addr.pointee.sa_len)
            if getnameinfo(ifa.ifa_addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                if !ip.hasPrefix("127.") {
                    if name == "en0" { return ip } // WiFi 优先
                    if fallback == nil { fallback = ip }
                }
            }
        }
        ptr = ifa.ifa_next
    }
    return fallback
}

// ---------- 二维码（CoreImage 原生，白底） ----------
func makeQR(_ string: String, size: CGFloat) -> NSImage? {
    guard let data = string.data(using: .utf8),
          let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    f.setValue(data, forKey: "inputMessage")
    f.setValue("M", forKey: "inputCorrectionLevel")
    guard let out = f.outputImage else { return nil }
    let scale = size / out.extent.width
    let scaled = out.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let white = CIImage(color: CIColor.white).cropped(to: scaled.extent)
    let composed = scaled.composited(over: white)
    let rep = NSCIImageRep(ciImage: composed)
    let img = NSImage(size: NSSize(width: size, height: size))
    img.addRepresentation(rep)
    return img
}

// ---------- 遥控管理器 ----------
final class RemoteControl: ObservableObject {
    static let shared = RemoteControl()

    @Published var urlString: String = ""
    @Published var qrImage: NSImage?
    @Published var running: Bool = false

    let token: String = String(UUID().uuidString.prefix(8))
    private let server = MiniHTTPServer()
    private let startPort = 8090

    func start() {
        server.handler = { [weak self] method, path, query, body in
            self?.route(method: method, path: path, query: query, body: body)
                ?? (500, "text/plain; charset=utf-8", "error")
        }
        guard let p = server.start(port: startPort) else { return }
        guard let ip = localIPAddress() else { return }
        let url = "http://\(ip):\(p)/?t=\(token)"
        DispatchQueue.main.async { [weak self] in
            self?.urlString = url
            self?.qrImage = makeQR(url, size: 240)
            self?.running = true
        }
    }

    private func route(method: String, path: String, query: [String: String], body: String)
        -> (Int, String, String)
    {
        guard query["t"] == token else {
            return (403, "text/plain; charset=utf-8", "Forbidden")
        }
        if method == "GET" && (path == "/" || path.isEmpty) {
            return (200, "text/html; charset=utf-8", remoteHTML)
        }
        if method == "GET" && path == "/api/state" {
            let s: [String: Any] = DispatchQueue.main.sync {
                AppDelegate.shared?.remoteState() ?? ["hasTimer": false]
            }
            let d = (try? JSONSerialization.data(withJSONObject: s)) ?? Data("{}".utf8)
            return (200, "application/json", String(data: d, encoding: .utf8) ?? "{}")
        }
        if method == "POST" && path == "/api/cmd" {
            let cmd = (try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]) ?? [:]
            let r: [String: Any] = DispatchQueue.main.sync {
                AppDelegate.shared?.remoteCommand(cmd) ?? ["ok": false]
            }
            let d = (try? JSONSerialization.data(withJSONObject: r)) ?? Data("{}".utf8)
            return (200, "application/json", String(data: d, encoding: .utf8) ?? "{}")
        }
        return (404, "text/plain; charset=utf-8", "Not Found")
    }
}

// ---------- 手机端页面（单文件，无外部依赖，会场无外网也能用） ----------
let remoteHTML = #"""
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>On Time 7 遥控</title>
<style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;background:#141414;color:#fff;padding:20px 16px 48px}
h1{font-size:18px;text-align:center;margin:0 0 4px}
.sub{text-align:center;color:#888;font-size:12px;margin-bottom:14px}
#time{font-size:76px;font-weight:700;text-align:center;margin:6px 0 2px;font-variant-numeric:tabular-nums;letter-spacing:2px}
#state{text-align:center;color:#aaa;font-size:14px;min-height:22px;margin-bottom:14px}
.row{display:flex;gap:10px;margin-bottom:12px}
button{flex:1;border:none;border-radius:12px;padding:16px 0;font-size:17px;font-weight:600;color:#fff;background:#2c2c2e}
button:active{opacity:.65}
button.primary{background:#b7472a}
button.blue{background:#0a84ff}
.sec{font-size:14px;color:#aaa;margin:18px 0 8px}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.grid button{padding:14px 0;font-size:15px}
.custom{display:flex;gap:10px;margin-top:10px}
.custom input{flex:1;min-width:0;border-radius:12px;border:1px solid #444;background:#1c1c1e;color:#fff;font-size:17px;padding:14px;text-align:center}
#err{display:none;text-align:center;color:#ff9f0a;font-size:13px;margin-top:14px}
</style>
</head>
<body>
<h1>On Time 7 · 手机遥控</h1>
<div class="sub">与电脑在同一 WiFi 下使用</div>
<div id="time">--:--</div>
<div id="state"></div>
<div class="row">
<button id="toggle" class="primary">⏸ 暂停</button>
<button id="reset">↺ 重置</button>
<button id="close">✕ 关闭</button>
</div>
<div class="sec">设置时长并开始</div>
<div class="grid">
<button data-min="10">10分钟</button>
<button data-min="15">15分钟</button>
<button data-min="20">20分钟</button>
<button data-min="30">30分钟</button>
<button data-min="45">45分钟</button>
<button data-min="60">60分钟</button>
</div>
<div class="custom">
<input id="mins" type="number" inputmode="numeric" placeholder="自定义分钟数">
<button id="go" class="blue" style="flex:0 0 110px">开始</button>
</div>
<div id="err">连接断开：请确认手机与电脑在同一 WiFi</div>
<script>
var T=new URLSearchParams(location.search).get('t')||'';
var timeEl=document.getElementById('time'),stateEl=document.getElementById('state'),
    errEl=document.getElementById('err'),toggleBtn=document.getElementById('toggle');
function fmt(s){s=Math.max(0,Math.round(s));var h=Math.floor(s/3600),m=Math.floor(s%3600/60),ss=s%60;
var p=function(n){return String(n).padStart(2,'0')};return h>0?h+':'+p(m)+':'+p(ss):p(m)+':'+p(ss);}
async function call(path,body){
var r=await fetch(path+'?t='+encodeURIComponent(T),{method:body?'POST':'GET',
headers:{'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
if(!r.ok)throw new Error(r.status);return r.json();}
async function refresh(){
try{var s=await call('/api/state');errEl.style.display='none';
if(s.hasTimer){timeEl.textContent=s.text||fmt(s.remaining);
stateEl.textContent=s.overTime?'已超时':(s.paused?'已暂停':'计时中');
toggleBtn.textContent=s.paused?'▶ 继续':'⏸ 暂停';}
else{timeEl.textContent='--:--';stateEl.textContent='电脑端未开始倒计时';toggleBtn.textContent='⏸ 暂停';}
}catch(e){errEl.style.display='block';}}
toggleBtn.onclick=async function(){try{await call('/api/cmd',{action:'toggle'});refresh();}catch(e){}};
document.getElementById('reset').onclick=async function(){try{await call('/api/cmd',{action:'reset'});refresh();}catch(e){}};
document.getElementById('close').onclick=async function(){try{await call('/api/cmd',{action:'close'});refresh();}catch(e){}};
document.querySelectorAll('.grid button').forEach(function(b){
b.onclick=async function(){try{await call('/api/cmd',{action:'set',seconds:parseInt(b.dataset.min,10)*60});refresh();}catch(e){}};});
document.getElementById('go').onclick=async function(){
var m=parseInt(document.getElementById('mins').value,10);
if(m>0){try{await call('/api/cmd',{action:'set',seconds:m*60});refresh();}catch(e){}}};
setInterval(refresh,1000);refresh();
</script>
</body>
</html>
"""#
