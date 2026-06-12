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
    private let restoreDelay: TimeInterval = 0.3

    private let logger = Logger(subsystem: "dev.kalala252.plainpaste", category: "paste")

    /// 復元待ちのスナップショット。連打されても最初のリッチな内容を保持し続ける。
    private var pendingSnapshot: PasteboardSnapshot?
    private var pendingRestore: DispatchWorkItem?
    /// 自分がプレーンテキストを書き込んだ直後の changeCount。
    /// ペーストボードの現在の内容が「自分が書いたもの」か「ユーザーがコピーしたもの」かの判別に使う。
    private var ownChangeCount = -1

    func performPlainPaste() {
        logger.info("hotkey fired")
        guard AXIsProcessTrusted() else {
            logger.error("not trusted for accessibility")
            promptForAccessibility()
            return
        }

        let pasteboard = NSPasteboard.general
        guard let plainText = PlainTextExtractor.plainText(from: pasteboard) else {
            logger.error("no plain text on pasteboard")
            NSSound.beep()
            return
        }
        logger.info("pasting \(plainText.count) chars")

        // 連打対策: 復元前に再度呼ばれた場合、ペーストボードには自分が書いた
        // プレーンテキストしか残っていないため、スナップショットを取り直すと
        // 元のリッチな内容を失う。その場合は前回のスナップショットを使い続ける。
        pendingRestore?.cancel()
        if pasteboard.changeCount != ownChangeCount {
            pendingSnapshot = PasteboardSnapshot(pasteboard: pasteboard)
        }

        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
        ownChangeCount = pasteboard.changeCount

        postCommandV()

        let restore = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // 復元待ちの間にユーザーが新たにコピーしていたら、それを上書きしない
            if pasteboard.changeCount == self.ownChangeCount {
                self.pendingSnapshot?.restore(to: pasteboard)
                self.logger.info("restored original pasteboard")
            } else {
                self.logger.info("skipped restore (pasteboard changed by user)")
            }
            self.pendingSnapshot = nil
            self.pendingRestore = nil
            self.ownChangeCount = -1
        }
        pendingRestore = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: restore)
    }

    /// ⌘V キーイベントを合成して送る。
    /// ユーザーはこの瞬間 ⌥⌘ を物理的に押したままなので、何もしないと
    /// 合成した ⌘V に ⌥ が合成されて「⌥⌘V」として届いてしまう
    /// (自分のホットキーを再発火させる無限ループにもなる)。
    /// 対策として、送出中は物理キーボードのイベントを抑制し、
    /// flags を .maskCommand のみに明示した上で annotated session tap に送る。
    private func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        logger.info("posted cmd+V (keyDown=\(keyDown != nil), keyUp=\(keyUp != nil))")
    }

    private func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
