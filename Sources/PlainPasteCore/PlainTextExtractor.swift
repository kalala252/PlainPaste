import AppKit

/// ペーストボードからプレーンテキストを取り出す。
/// 通常は `.string` をそのまま使い、プレーン文字列を持たない
/// リッチテキスト(RTF / HTML)しか無い場合は属性付き文字列経由で変換する。
public enum PlainTextExtractor {
    public static func plainText(from pasteboard: NSPasteboard) -> String? {
        if let string = pasteboard.string(forType: .string) {
            return string
        }
        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
               data: rtf,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            return attributed.string
        }
        if let html = pasteboard.data(forType: .html),
           let attributed = try? NSAttributedString(
               data: html,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ) {
            return attributed.string
        }
        return nil
    }
}
