import Carbon
import Cocoa

class HotKeyManager {
    // Unique ID for our hotkey
    private let hotKeyID = EventHotKeyID(signature: 0x4D434244, id: 1) // 'MCBD', 1
    private var eventHandler: EventHandlerRef?
    var onHotKeyTriggered: (() -> Void)?
    
    init() {}
    
    func registerHotKey() {
        // V key is 9
        let vKeyCode = 9
        // Cmd + Shift
        let modifiers = cmdKey | shiftKey
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(vKeyCode),
                                         UInt32(modifiers),
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }
        
        // Install Event Handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        
        // We need a C-function pointer. Swift closures capturing context can't be passed directly easily
        // without an @convention(c) wrapper or using a global/static proxy.
        // For simplicity, we will use a self-contained closure if possible, or a static handler.
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            // Reconstruct self
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            manager.onHotKeyTriggered?()
            
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)
        
        print("Hotkey Registered: Cmd+Shift+V")
    }
    
    func unregister() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}
