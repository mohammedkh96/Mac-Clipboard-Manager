import SwiftUI
import AppKit
import ServiceManagement
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
            window.setContentSize(NSSize(width: 400, height: 350))
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
    @AppStorage("autoDeleteInterval") private var autoDeleteInterval: Int = 0
    @AppStorage("historyLimit") private var historyLimit: Int = 100
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled: Bool = true
    @AppStorage("showCountInMenuBar") private var showCountInMenuBar: Bool = false
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
                
                Section(header: Text("Startup")) {
                    if #available(macOS 13.0, *) {
                        Toggle("Launch at Login", isOn: Binding(
                            get: { SMAppService.mainApp.status == .enabled },
                            set: { newValue in
                                do {
                                    if newValue {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                } catch {
                                    print("Failed to update login item: \(error)")
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    } else {
                        Text("Launch at Login requires macOS 13.0+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Behavior")) {
                    Toggle("Sound Effects", isOn: $soundEffectsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    
                    Toggle("Show Item Count in Menu Bar", isOn: $showCountInMenuBar)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    
                    Picker("History Limit:", selection: $historyLimit) {
                        Text("50 items").tag(50)
                        Text("100 items").tag(100)
                        Text("200 items").tag(200)
                        Text("500 items").tag(500)
                        Text("Unlimited").tag(0)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Maximum number of items to keep in history. Set to Unlimited for no limit.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Storage Management")) {
                    Picker("Auto-delete items:", selection: $autoDeleteInterval) {
                        Text("Never").tag(0)
                        Text("After 3 Days").tag(3)
                        Text("After 7 Days").tag(7)
                        Text("After 30 Days").tag(30)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Unpinned items older than the selected period will be automatically removed on app launch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                
                VStack(spacing: 5) {
                    Text("Mac Clipboard Manager")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version 4.0.0 (2025)")
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    Text("Designed & Developed by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Eng. Mohammed Ahmed")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                // Social Links
                HStack(spacing: 20) {
                    // GitHub
                    Link(destination: URL(string: "https://github.com/mohammedkh96")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "cube.transparent") // Placeholder for GitHub if no asset
                                .font(.system(size: 20))
                            Text("GitHub")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Instagram
                    Link(destination: URL(string: "https://www.instagram.com/eng.mohammed.omar/")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera") // Placeholder for Instagram
                                .font(.system(size: 20))
                            Text("Instagram")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Website
                    Link(destination: URL(string: "https://eng-mohammed-omar.vercel.app/")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                            Text("Website")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
                .foregroundColor(.secondary)
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 400, height: 350) // Increased height for new section
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
