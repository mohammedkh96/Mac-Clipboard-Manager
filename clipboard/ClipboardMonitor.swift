import Cocoa
import Combine

struct ClipboardItem: Identifiable, Hashable, Codable {
    let id: UUID
    let content: String // For now, just text. Later: enum for Image/RTF
    let date: Date
    let appBundleID: String?
    var isPinned: Bool
    var color: String? // Hex code or name (e.g. "red", "blue")
    
    init(id: UUID = UUID(), content: String, appBundleID: String? = nil, date: Date = Date(), isPinned: Bool = false, color: String? = nil) {
        self.id = id
        self.content = content
        self.date = date
        self.appBundleID = appBundleID
        self.isPinned = isPinned
        self.color = color
    }
}

@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var history: [ClipboardItem] = [] {
        didSet {
            saveHistory()
        }
    }
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private let historyKey = "ClipboardHistory_v1"
    
    // Ignored apps (e.g. keychain access, etc - can be populated later)
    var ignoredApps: [String] = []

    init() {
        // Load history first
        self.loadHistory()
        
        // Initial check to sync with current state without duplicating if needed
        lastChangeCount = pasteboard.changeCount
        
        startCloudSync()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkClipboard()
            }
        }
    }
    
    func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // Retrieve content
        if let newString = pasteboard.string(forType: .string) {
            // Deduplicate: Don't add if it's exactly the same as the last item
            if let lastItem = history.first, lastItem.content == newString {
                return
            }
            
            let newItem = ClipboardItem(content: newString, appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
            
            // UI updates must be on main thread
            DispatchQueue.main.async {
                self.history.insert(newItem, at: 0)
                // Limit history size
                if self.history.count > 100 {
                    self.history.removeLast()
                }
            }
        }
    }
    
    func copyToClipboard(item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        // Updating changeCount happens automatically, so our monitor will see it.
        // We might want to ignore our own copy? For now let it be "top of stack".
    }
    
    func clearHistory() {
        history.removeAll()
    }
    
    func updateItem(id: UUID, newContent: String) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        
        // We modify the existing item (struct) copy
        var item = history[index]
        // Create new item with updated content, but keep old metadata if relevant? 
        // Actually, if we edit text, we might want to update date. But for pin/color we want methods.
        // Let's just create a new one with updated content.
        let newItem = ClipboardItem(id: item.id, content: newContent, appBundleID: item.appBundleID, date: Date(), isPinned: item.isPinned, color: item.color)
        
        history[index] = newItem
    }
    
    func togglePin(id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        var item = history[index]
        item.isPinned.toggle()
        history[index] = item
        // Move to top/sort happens in View or we can sort here? 
        // Standard practice: "Pinning" usually just flags it. View handles display order.
    }
    
    func setColor(id: UUID, color: String?) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        var item = history[index]
        item.color = color
        history[index] = item
    }
    
    func deleteItem(id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history.remove(at: index)
    }
    
    // MARK: - Cloud Sync
    func startCloudSync() {
        NSUbiquitousKeyValueStore.default.synchronize()
        NotificationCenter.default.addObserver(self, selector: #selector(cloudDataChanged(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        // Initial load check
        loadFromCloud()
    }
    
    @objc func cloudDataChanged(_ notification: Notification) {
        Task { @MainActor in
            self.loadFromCloud()
        }
    }
    
    // Simple Sync Policy: Pinned items UUIDs + simplified metadata
    // For now, we only sync which IDs are pinned, or if we want to sync the content of pinned items?
    // Let's assume we sync the Content of items that are pinned.
    // NOTE: This basic implementation only syncs a small array of pinned items. Large clips might fail KV limits (1MB total).
    
    private func saveToCloud() {
        // Find pinned items
        let pinned = history.filter { $0.isPinned }
        do {
            let data = try JSONEncoder().encode(pinned)
            NSUbiquitousKeyValueStore.default.set(data, forKey: "pinned_items")
            NSUbiquitousKeyValueStore.default.synchronize()
        } catch {
            print("Cloud Save Error: \(error)")
        }
    }
    
    private func loadFromCloud() {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: "pinned_items") else { return }
        do {
            let cloudPinned = try JSONDecoder().decode([ClipboardItem].self, from: data)
            // Merge strategy: Add any cloud pinned items that we don't have locally.
            // If we have them, ensure they are pinned.
            
            for cloudItem in cloudPinned {
                if let index = history.firstIndex(where: { $0.id == cloudItem.id }) {
                    // Update local to match cloud status (pinned)
                    if !history[index].isPinned {
                        history[index].isPinned = true
                    }
                } else {
                    // Item doesn't exist locally, insert it at top
                    history.insert(cloudItem, at: 0)
                }
            }
        } catch {
            print("Cloud Load Error: \(error)")
        }
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(history)
            UserDefaults.standard.set(encoded, forKey: historyKey)
            
            // Trigger cloud save if pinned items changed?
            // Simple optimization: call saveToCloud every time for now (debouncing better in prod)
            saveToCloud()
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            self.history = decoded
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}
