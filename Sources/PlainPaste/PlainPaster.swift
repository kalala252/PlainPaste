import AppKit
import Carbon.HIToolbox
import os
import PlainPasteCore

/// プレーン貼り付けの本体。
/// 1. ペーストボードの現在の内容を退避
/// 2. プレーンテキストだけを書き込む
/// 3. ⌘V のキーイベントを合成して最前面のアプリに送る
/// 4. 少し待ってから元の内容を復元する(クリップボードを汚さない)
final class PlainPaster {
    /// ⌘V を送ってから元のクリップボードを復元するまでの待ち時間。
    /// 受け取り側アプリがペーストボードを読み終えるのを待つ必要がある。
    private let restoreDelay: TimeInterval
    private let pasteboard: NSPasteboard
    private let isTrusted: () -> Bool
    private let sendPaste: () -> Bool

    init(
        pasteboard: NSPasteboard = .general,
        restoreDelay: TimeInterval = 0.3,
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        sendPaste: @escaping () -> Bool = { PlainPaster.postCommandV() }
    ) {
        self.pasteboard = pasteboard
        self.restoreDelay = restoreDelay
        self.isTrusted = isTrusted
        self.sendPaste = sendPaste
    }

    private let logger = Logger(subsystem: "dev.kalala252.plainpaste", category: "paste")

    /// 復元待ちのスナップショット。連打されても最初のリッチな内容を保持し続ける。
    private var pendingSnapshot: PasteboardSnapshot?
    private var pendingRestore: DispatchWorkItem?
    /// 自分がプレーンテキストを書き込んだ直後の changeCount。
    /// ペーストボードの現在の内容が「自分が書いたもの」か「ユーザーがコピーしたもの」かの判別に使う。
    private var ownChangeCount = -1

    func performPlainPaste() {
        logger.info("hotkey fired")
        guard isTrusted() else {
            logger.error("not trusted for accessibility")
            promptForAccessibility()
            return
        }

        let sourceChangeCount = pasteboard.changeCount
        guard let plainText = PlainTextExtractor.plainText(from: pasteboard) else {
            logger.error("no plain text on pasteboard")
            NSSound.beep()
            return
        }
        logger.info("pasting \(plainText.count) chars")

        // 連打対策: 復元前に再度呼ばれた場合、ペーストボードには自分が書いた
        // プレーンテキストしか残っていないため、スナップショットを取り直すと
        // 元のリッチな内容を失う。その場合は前回のスナップショットを使い続ける。
        let snapshot = pasteboard.changeCount == ownChangeCount
            ? pendingSnapshot : PasteboardSnapshot(pasteboard: pasteboard)
        // HTMLの変換や遅延データの取得中にコピー内容が変わっていたら中止する。
        guard pasteboard.changeCount == sourceChangeCount else { return }
        pendingRestore?.cancel()
        pendingSnapshot = snapshot

        pasteboard.clearContents()
        ownChangeCount = pasteboard.changeCount
        guard pasteboard.setString(plainText, forType: .string) else {
            finishPendingPaste()
            return
        }
        ownChangeCount = pasteboard.changeCount

        guard sendPaste() else {
            logger.error("could not create paste key events")
            finishPendingPaste()
            return
        }

        let restore = DispatchWorkItem { [weak self] in
            self?.finishPendingPaste()
        }
        pendingRestore = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: restore)
    }

    /// 通常の復元、送信失敗、アプリ終了のいずれでも同じ条件で復元する。
    func finishPendingPaste() {
        pendingRestore?.cancel()
        if let snapshot = pendingSnapshot, pasteboard.changeCount == ownChangeCount {
            snapshot.restore(to: pasteboard)
        }
        pendingSnapshot = nil
        pendingRestore = nil
        ownChangeCount = -1
    }

    /// ⌘V キーイベントを合成して送る。
    /// ユーザーはこの瞬間 ⌥⌘ を物理的に押したままなので、何もしないと
    /// 合成した ⌘V に ⌥ が合成されて「⌥⌘V」として届いてしまう
    /// (自分のホットキーを再発火させる無限ループにもなる)。
    /// 対策として、送出中は物理キーボードのイベントを抑制し、
    /// flags を .maskCommand のみに明示した上で annotated session tap に送る。
    private static func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        guard let keyDown, let keyUp else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    private func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
