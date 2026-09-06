import AppKit
import Carbon.HIToolbox
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "dev.kalala252.plainpaste", category: "app")
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?
    private let paster = PlainPaster()

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
        ) { [paster] in
            paster.performPlainPaste()
        }

        if hotKey == nil {
            let alert = NSAlert()
            alert.messageText = "ホットキーを登録できませんでした"
            alert.informativeText = "⌥⌘V が他のアプリで使用されている可能性があります。"
            alert.runModal()
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
