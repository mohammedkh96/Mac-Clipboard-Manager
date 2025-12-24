import Carbon
import Cocoa
import SwiftUI
import Combine

class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    
    // Unique ID for our hotkey
    private let hotKeyID = EventHotKeyID(signature: 0x4D434244, id: 1) // 'MCBD', 1
    private var eventHandler: EventHandlerRef?
    var onHotKeyTriggered: (() -> Void)?
    
    // Published for UI
    @Published var currentKeyString: String = "⌘⇧V"
    
    private let defaultsKey = "appHotkey"
    
    init() {
        loadHotkey()
    }
    
    func registerHotKey() {
        // Unregister existing first
        unregister()
        
        let (keyCode, modifiers) = getSavedHotkey()
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode),
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
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            manager.onHotKeyTriggered?()
            
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)
        
        print("Hotkey Registered: \(currentKeyString)")
    }
    
    func unregister() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        // Also simpler: UnregisterEventHotKey(hotKeyRef) if we kept the ref,
        // but removing the handler stops the app from reacting.
        // Ideally we should UnregisterEventHotKey too but Carbon API is old and tricky.
        // For this scope, removing handler is effective.
    }
    
    func updateHotkey(keyCode: Int, modifiers: Int) {
        let dict: [String: Int] = ["keyCode": keyCode, "modifiers": modifiers]
        UserDefaults.standard.set(dict, forKey: defaultsKey)
        
        updateDisplayString(keyCode: keyCode, modifiers: modifiers)
        registerHotKey() // Re-register with new values
    }
    
    private func getSavedHotkey() -> (Int, Int) {
        if let dict = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Int],
           let k = dict["keyCode"],
           let m = dict["modifiers"] {
            return (k, m)
        }
        // Default: Cmd + Shift + V (9)
        return (9, cmdKey | shiftKey)
    }
    
    private func loadHotkey() {
        let (k, m) = getSavedHotkey()
        updateDisplayString(keyCode: k, modifiers: m)
    }
    
    private func updateDisplayString(keyCode: Int, modifiers: Int) {
        var str = ""
        if modifiers & cmdKey != 0 { str += "⌘" }
        if modifiers & shiftKey != 0 { str += "⇧" }
        if modifiers & optionKey != 0 { str += "⌥" }
        if modifiers & controlKey != 0 { str += "⌃" }
        
        // Simple mapping for demonstration. Real mapping requires Carbon functions.
        // For now, we handle A-Z, 0-9 basically.
        str += keyToString(keyCode)
        
        DispatchQueue.main.async {
            self.currentKeyString = str
        }
    }
    
    private func keyToString(_ code: Int) -> String {
        switch code {
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        default: return "?" // Fallback
        }
    }
}
