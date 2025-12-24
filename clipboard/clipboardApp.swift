import SwiftUI
import AppKit
import Carbon

@main
struct clipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSPanel!
    var monitor = ClipboardMonitor() // Shared monitor
    var historyView: ClipboardHistoryView?
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var hotKeyManager = HotKeyManager.shared
    
    var settingsWindow: NSWindow?
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle Dock Icon Click
        togglePopover(sender)
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set fallback icon if needed
        if NSApp.applicationIconImage.name() == "NSApplicationIcon" { // Default generic icon
             let image = NSImage(systemSymbolName: "clipboard.fill", accessibilityDescription: "App Icon")
             NSApp.applicationIconImage = image
        }

        // 0. Check Permissions
        checkAccessibilityPermissions()

        // 1. Start Monitoring
        monitor.startMonitoring()
        
        // 2. Setup Status Bar
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem.button {
            // "doc.on.clipboard" is a valid SF Symbol for macOS 11+
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePopover(_:))
        }
        
        // 3. Setup Popover (The UI)
        let swiftUIView = ClipboardHistoryView(monitor: monitor, onPaste: { [weak self] item in
            self?.pasteItem(item)
        }, onClose: { [weak self] in
            self?.closePopover(nil)
        }, onSettings: { [weak self] in
            self?.openSettings()
            self?.closePopover(nil)
        })
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 500)
        popover.behavior = .transient // Close when denied focus
        popover.contentViewController = NSHostingController(rootView: swiftUIView)
        
        // 4. Register Global Hotkey
        hotKeyManager.onHotKeyTriggered = { [weak self] in
            self?.togglePopover(nil)
        }
        hotKeyManager.registerHotKey()
        
        print("MacClipboardManager started.")
    }
    
    nonisolated func checkAccessibilityPermissions() {
        // We use MainActor.assumeIsolated or similar if we needed main thread, 
        // but here we just want to avoid the strict Actor check on the global var.
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options: [String: Bool] = [promptKey: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("Accessibility not enabled. Prompting user...")
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Make app active to receive input
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
    
    func pasteItem(_ item: ClipboardItem) {
        monitor.copyToClipboard(item: item)
        closePopover(nil)
        
        // "Paste" action
        // We need to hide our app, then Simulate Cmd+V
        NSApp.hide(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }
    
    func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        
        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
    
    func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.setContentSize(NSSize(width: 400, height: 250))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    
    @State private var isRecording = false
    
    var body: some View {
        TabView {
            // General / Appearance Tab
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Keyboard Shortcut")) {
                    HStack {
                        Text("Toggle Clipboard:")
                        Spacer()
                        Button(action: {
                            isRecording = true
                        }) {
                            Text(isRecording ? "Press Keys..." : hotKeyManager.currentKeyString)
                                .font(.system(.body, design: .monospaced))
                                .padding(6)
                                .background(isRecording ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(isRecording ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .background(KeyRecorder(isRecording: $isRecording, manager: hotKeyManager))
                    }
                    .padding(.vertical, 8)
                    
                    Text("Click to record a new shortcut.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // About Tab
            VStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                
                Text("Mac Clipboard Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Version 3.0.0")
                    .foregroundColor(.secondary)
                
                Text("Designed & Developed by\nHaji Salam")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .padding()
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 400, height: 250)
    }
}

struct KeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var manager: HotKeyManager
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyPress = { code, mods in
            if isRecording {
                let carbonMods = convertModifiers(mods)
                manager.updateHotkey(keyCode: parseInt(code), modifiers: carbonMods)
                isRecording = false
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func parseInt(_ code: UInt16) -> Int {
        return Int(code)
    }
    
    private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.shift) { mods |= shiftKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        return mods
    }
}

class KeyCaptureView: NSView {
    var onKeyPress: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyPress?(event.keyCode, event.modifierFlags)
    }
}
