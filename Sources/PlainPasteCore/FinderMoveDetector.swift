import AppKit

/// ⌥⌘V をプレーン貼り付けに使わず、Finder の「項目をここに移動」に回すかを判定する。
/// PlainPaste は ⌥⌘V をシステム全体で登録しているため、何もしないと
/// Finder でコピーしたファイルを移動するショートカットが使えなくなる。
public enum FinderMoveDetector {
    public static let finderBundleIdentifier = "com.apple.finder"

    /// 最前面が Finder で、ペーストボードにファイルがあるときに true を返す。
    /// Finder でも名前の編集中に文字列を貼る場合は、従来どおりプレーン貼り付けにする。
    public static func shouldPassThrough(
        frontmostBundleIdentifier: String?,
        pasteboard: NSPasteboard
    ) -> Bool {
        guard frontmostBundleIdentifier == finderBundleIdentifier else { return false }
        return pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }
}
