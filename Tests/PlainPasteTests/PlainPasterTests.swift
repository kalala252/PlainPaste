import AppKit
import Testing
@testable import PlainPaste

@MainActor @Suite struct PlainPasterTests {
    private func withPasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
        let board = NSPasteboard(name: .init("dev.plainpaste.paster-tests.\(UUID())"))
        defer { board.releaseGlobally() }
        try body(board)
    }

    private func putRichText(_ text: String, on board: NSPasteboard) throws -> Data {
        let attributed = NSAttributedString(string: text)
        let rtf = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(rtf, forType: .rtf)
        board.clearContents()
        #expect(board.writeObjects([item]))
        return rtf
    }

    @Test func terminationRestoresPendingRichText() throws {
        try withPasteboard { board in
            let rtf = try putRichText("元の内容", on: board)
            let paster = PlainPaster(pasteboard: board, restoreDelay: 60,
                isTrusted: { true }, sendPaste: {
                    #expect(board.string(forType: .string) == "元の内容")
                    #expect(board.data(forType: .rtf) == nil)
                    return true
                })
            paster.performPlainPaste()
            paster.finishPendingPaste()
            #expect(board.data(forType: .rtf) == rtf)
        }
    }

    @Test func repeatedPastePreservesOriginalFormatting() throws {
        try withPasteboard { board in
            let rtf = try putRichText("連続で貼り付け", on: board)
            var sends = 0
            let paster = PlainPaster(pasteboard: board, restoreDelay: 60,
                isTrusted: { true }, sendPaste: { sends += 1; return true })
            paster.performPlainPaste()
            paster.performPlainPaste()
            paster.finishPendingPaste()
            #expect(sends == 2)
            #expect(board.data(forType: .rtf) == rtf)
        }
    }

    @Test func newCopyIsNotOverwrittenOnTermination() throws {
        try withPasteboard { board in
            _ = try putRichText("古い内容", on: board)
            let paster = PlainPaster(pasteboard: board, restoreDelay: 60,
                isTrusted: { true }, sendPaste: { true })
            paster.performPlainPaste()
            let newRTF = try putRichText("新しくコピー", on: board)
            paster.finishPendingPaste()
            #expect(board.string(forType: .string) == "新しくコピー")
            #expect(board.data(forType: .rtf) == newRTF)
        }
    }

    @Test func newCopyThenPasteRestoresTheNewCopy() throws {
        try withPasteboard { board in
            _ = try putRichText("最初", on: board)
            let paster = PlainPaster(pasteboard: board, restoreDelay: 60,
                isTrusted: { true }, sendPaste: { true })
            paster.performPlainPaste()
            let newRTF = try putRichText("次", on: board)
            paster.performPlainPaste()
            paster.finishPendingPaste()
            #expect(board.string(forType: .string) == "次")
            #expect(board.data(forType: .rtf) == newRTF)
        }
    }

    @Test func failedKeyEventCreationRestoresImmediately() throws {
        try withPasteboard { board in
            let rtf = try putRichText("失敗しても残す", on: board)
            let paster = PlainPaster(pasteboard: board,
                isTrusted: { true }, sendPaste: { false })
            paster.performPlainPaste()
            #expect(board.data(forType: .rtf) == rtf)
            #expect(board.string(forType: .string) == "失敗しても残す")
        }
    }
}
