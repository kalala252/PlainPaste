import AppKit

/// ペーストボードの全アイテムを型ごとの生データとして退避し、
/// あとで元どおり復元するためのスナップショット。
/// プレーン貼り付けのためにペーストボードを一時的に書き換えても、
/// ユーザーのクリップボード(リッチテキストや画像)を失わないようにする。
public struct PasteboardSnapshot {
    private let items: [[String: Data]]

    public init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var typeToData = [String: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    typeToData[type.rawValue] = data
                }
            }
            return typeToData
        }
    }

    public var isEmpty: Bool { items.isEmpty }

    public func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { typeToData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typeToData {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}
