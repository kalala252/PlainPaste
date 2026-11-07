import Carbon.HIToolbox

/// Carbon の RegisterEventHotKey によるグローバルホットキー。
/// アクセシビリティ権限なしでシステム全体のキー入力を受け取れる。
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onPress: () -> Void
    private let keyCode: UInt32
    private let modifiers: UInt32

    /// - Parameters:
    ///   - keyCode: 仮想キーコード(例: `kVK_ANSI_V`)
    ///   - modifiers: Carbon の修飾キーフラグ(例: `cmdKey | optionKey`)
    init?(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        self.onPress = onPress
        self.keyCode = keyCode
        self.modifiers = modifiers

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C関数ポインタにはクロージャを渡せないため、self を userData 経由で引き回す
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().onPress()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
        guard installStatus == noErr else { return nil }

        // 初期化失敗時もdeinitで一度だけ解放する。
        guard register() else { return nil }
    }

    /// ホットキーを登録する。登録済みなら何もしない。
    @discardableResult
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }
        let hotKeyID = EventHotKeyID(signature: OSType(0x504C5354), id: 1) // 'PLST'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    /// 同じキーの組み合わせを他のアプリへ届けるため、一時的に登録を外す。
    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
