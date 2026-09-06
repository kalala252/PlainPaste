import AppKit
import Testing
@testable import PlainPasteCore

/// テストごとに独立した名前付きペーストボードを使い、システムのクリップボードを汚さない
final class PasteboardTestCase {
    let pasteboard: NSPasteboard

    init() {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("dev.plainpaste.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
    }

    deinit {
        pasteboard.releaseGlobally()
    }
}

@MainActor @Suite struct PlainTextExtractorTests {
    @Test func extractsPlainString() {
        let testCase = PasteboardTestCase()
        testCase.pasteboard.setString("こんにちは", forType: .string)

        #expect(PlainTextExtractor.plainText(from: testCase.pasteboard) == "こんにちは")
    }

    @Test func extractsPlainTextFromRTFOnly() throws {
        let attributed = NSAttributedString(
            string: "太字のテキスト",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        let rtfData = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let testCase = PasteboardTestCase()
        testCase.pasteboard.setData(rtfData, forType: .rtf)

        #expect(PlainTextExtractor.plainText(from: testCase.pasteboard) == "太字のテキスト")
    }

    @Test func returnsNilForEmptyPasteboard() {
        let testCase = PasteboardTestCase()

        #expect(PlainTextExtractor.plainText(from: testCase.pasteboard) == nil)
    }
}

@MainActor @Suite struct PasteboardSnapshotTests {
    @Test func restoresMultipleTypes() throws {
        let attributed = NSAttributedString(string: "リッチテキスト")
        let rtfData = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let testCase = PasteboardTestCase()
        let item = NSPasteboardItem()
        item.setString("リッチテキスト", forType: .string)
        item.setData(rtfData, forType: .rtf)
        testCase.pasteboard.writeObjects([item])

        let snapshot = PasteboardSnapshot(pasteboard: testCase.pasteboard)

        // プレーン貼り付けと同じように内容を上書き
        testCase.pasteboard.clearContents()
        testCase.pasteboard.setString("一時的な内容", forType: .string)
        #expect(testCase.pasteboard.pasteboardItems?.first?.data(forType: .rtf) == nil)

        snapshot.restore(to: testCase.pasteboard)

        let restored = testCase.pasteboard.pasteboardItems?.first
        #expect(restored?.string(forType: .string) == "リッチテキスト")
        #expect(restored?.data(forType: .rtf) == rtfData)
    }

    @Test func emptyPasteboardYieldsEmptySnapshot() {
        let testCase = PasteboardTestCase()

        #expect(PasteboardSnapshot(pasteboard: testCase.pasteboard).isEmpty)
    }
}
