import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// メニューバー常駐(Dock に表示しない)
app.setActivationPolicy(.accessory)
app.run()
