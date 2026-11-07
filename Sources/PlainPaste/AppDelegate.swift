import AppKit
import Carbon.HIToolbox
import os
import PlainPasteCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "dev.kalala252.plainpaste", category: "app")
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?
    private let paster = PlainPaster()
    /// Finder へ ⌥⌘V を素通しした後、ホットキーを登録し直すまでの待ち時間。
    /// 合成したイベントが Finder に届く前に登録し直すと、自分で受け取ってしまう。
    private let passThroughReregisterDelay: TimeInterval = 0.3

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("launched, trusted=\(AXIsProcessTrusted())")
        setupStatusItem()
        registerHotKey()
        requestAccessibilityIfNeeded()
        logger.info("hotkey registered=\(self.hotKey != nil)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        paster.finishPendingPaste()
    }

    // MARK: - メニューバー

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "PlainPaste"
        )

        let menu = NSMenu()

        let shortcutInfo = NSMenuItem(title: "⌥⌘V でプレーンテキストをペースト", action: nil, keyEquivalent: "")
        shortcutInfo.isEnabled = false
        menu.addItem(shortcutInfo)
        let finderInfo = NSMenuItem(title: "Finder でファイルをコピー中は ⌥⌘V で移動", action: nil, keyEquivalent: "")
        finderInfo.isEnabled = false
        menu.addItem(finderInfo)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "アクセシビリティ設定を開く…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "PlainPaste について",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "PlainPaste を終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        for menuItem in menu.items where menuItem.action != #selector(NSApplication.terminate(_:)) {
            menuItem.target = self
        }

        item.menu = menu
        statusItem = item
    }

    // MARK: - ホットキー

    private func registerHotKey() {
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | optionKey)
        ) { [weak self] in
            self?.handleHotKey()
        }

        if hotKey == nil {
            let alert = NSAlert()
            alert.messageText = "ホットキーを登録できませんでした"
            alert.informativeText = "⌥⌘V が他のアプリで使用されている可能性があります。"
            alert.runModal()
        }
    }

    private func handleHotKey() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if FinderMoveDetector.shouldPassThrough(frontmostBundleIdentifier: frontmost, pasteboard: .general) {
            passThroughToFinder()
        } else {
            paster.performPlainPaste()
        }
    }

    /// Finder の「項目をここに移動」(⌥⌘V)を使えるよう、ホットキーの登録を外して ⌥⌘V をそのまま送る。
    private func passThroughToFinder() {
        logger.info("passing ⌥⌘V through to Finder")
        guard AXIsProcessTrusted() else {
            requestAccessibilityIfNeeded()
            return
        }
        guard let hotKey else { return }

        hotKey.unregister()
        if !PlainPaster.postV(flags: [.maskCommand, .maskAlternate]) {
            logger.error("could not create move key events")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + passThroughReregisterDelay) { [weak self] in
            guard let self, let hotKey = self.hotKey else { return }
            if !hotKey.register() {
                self.logger.error("could not re-register hotkey")
            }
        }
    }

    // MARK: - アクセシビリティ権限

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
