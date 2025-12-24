import Cocoa
import Combine
import SwiftUI // For Image

enum ClipboardItemType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Hashable, Codable {
    let id: UUID
    let content: String // Text content or Description for image
    let date: Date
    let appBundleID: String?
    var isPinned: Bool
    var color: String?
    
    // V4 New Types
    var type: ClipboardItemType = .text // Default to text for migration
    var imagePath: String? // Filename in AppSupport if type is .image
    
    // V6 Rich Text
    var rtfPath: String?
    var htmlPath: String?
    
    init(id: UUID = UUID(), content: String, appBundleID: String? = nil, date: Date = Date(), isPinned: Bool = false, color: String? = nil, type: ClipboardItemType = .text, imagePath: String? = nil, rtfPath: String? = nil, htmlPath: String? = nil) {
        self.id = id
        self.content = content
        self.date = date
        self.appBundleID = appBundleID
        self.isPinned = isPinned
        self.color = color
        self.type = type
        self.imagePath = imagePath
        self.rtfPath = rtfPath
        self.htmlPath = htmlPath
    }
}

@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var history: [ClipboardItem] = [] {
        didSet {
            saveHistory()
        }
    }
    
    // Auto-Delete Setting (days). 0 = Never
    @AppStorage("autoDeleteInterval") private var autoDeleteInterval: Int = 0
    @AppStorage("historyLimit") private var historyLimit: Int = 100
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private let historyKey = "ClipboardHistory_v1"
    
    init() {
        self.loadHistory()
        lastChangeCount = pasteboard.changeCount
        
        startCloudSync()
        
        // Run Cleanup on launch
        cleanupOldItems()
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
        
        // 1. Check for Image FIRST (Priority)
        // Many apps that copy images also put text metadata on pasteboard (file paths, descriptions)
        // So we must check for image data first to avoid treating it as text
        if let tiffData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            print("Found Image Data")
            let filename = UUID().uuidString + ".png"
            if saveDataToDisk(data: tiffData, filename: filename) {
                let newItem = ClipboardItem(content: "Image", appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, type: .image, imagePath: filename)
                 DispatchQueue.main.async {
                    self.history.insert(newItem, at: 0)
                    self.limitHistory()
                }
                return
            }
        }
        
        // 2. Check for Text with Rich Text augmentation
        if let newString = pasteboard.string(forType: .string) {
            // Check for duplicates
            if let lastItem = history.first, lastItem.content == newString { return }
            
            print("Found Text: \(newString.prefix(20))...")
            
            var rtfPath: String? = nil
            var htmlPath: String? = nil
            
            // Check for RTF
            if let rtfData = pasteboard.data(forType: .rtf) {
                print("Found RTF Data")
                let filename = UUID().uuidString + ".rtf"
                if saveDataToDisk(data: rtfData, filename: filename) {
                    rtfPath = filename
                }
            }
            
            // Check for HTML
            if let htmlData = pasteboard.data(forType: .html) {
                print("Found HTML Data")
                let filename = UUID().uuidString + ".html"
                if saveDataToDisk(data: htmlData, filename: filename) {
                    htmlPath = filename
                }
            }
            
            let newItem = ClipboardItem(
                content: newString,
                appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                type: .text,
                rtfPath: rtfPath,
                htmlPath: htmlPath
            )
            
            DispatchQueue.main.async {
                self.history.insert(newItem, at: 0)
                self.limitHistory()
            }
            return
        }
    }
    
    private func limitHistory() {
        // 0 = unlimited
        guard historyLimit > 0, self.history.count > historyLimit else { return }
        while self.history.count > historyLimit {
            let removed = self.history.popLast()
            cleanupFiles(for: removed)
        }
    }
    
    // Auto-Delete Logic
    func cleanupOldItems() {
        guard autoDeleteInterval > 0 else { return }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteInterval, to: Date()) ?? Date()
        
        // Filter Items to keep
        // Keep if (Pinned) OR (Date > Cutoff)
        // Delete if (!Pinned) AND (Date < Cutoff)
        
        var toKeep: [ClipboardItem] = []
        var toDelete: [ClipboardItem] = []
        
        for item in history {
            if item.isPinned || item.date > cutoffDate {
                toKeep.append(item)
            } else {
                toDelete.append(item)
            }
        }
        
        // Perform Deletion (mainly for images)
        for item in toDelete {
            cleanupFiles(for: item)
        }
        
        if history.count != toKeep.count {
            print("Auto-Delete: Removed \(history.count - toKeep.count) items older than \(autoDeleteInterval) days.")
            history = toKeep
        }
    }
    
    private func cleanupFiles(for item: ClipboardItem?) {
        guard let item = item else { return }
        if let path = item.imagePath { deleteFileFromDisk(filename: path) }
        if let path = item.rtfPath { deleteFileFromDisk(filename: path) }
        if let path = item.htmlPath { deleteFileFromDisk(filename: path) }
    }
    
    // MARK: - Disk I/O
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("ClipboardManagerData") // Renamed directory for generic usage
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private func saveDataToDisk(data: Data, filename: String) -> Bool {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save data: \(error)")
            return false
        }
    }
    
    private func deleteFileFromDisk(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    func loadData(filename: String) -> Data? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }
    
    func loadImage(filename: String) -> NSImage? {
        // Kept for convenience
        guard let data = loadData(filename: filename) else { return nil }
        return NSImage(data: data)
    }
    
    // MARK: - Standard Methods
    func copyToClipboard(item: ClipboardItem) {
        pasteboard.clearContents()
        
        if item.type == .image, let filename = item.imagePath, let image = loadImage(filename: filename) {
            pasteboard.writeObjects([image])
        } else {
            // prioritize RTF
            if let rtfPath = item.rtfPath, let rtfData = loadData(filename: rtfPath) {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // fallback/concurrent HTML
            if let htmlPath = item.htmlPath, let htmlData = loadData(filename: htmlPath) {
                pasteboard.setData(htmlData, forType: .html)
            }
            
            // Always set string as fallback
            pasteboard.setString(item.content, forType: .string)
        }
    }
    
    func clearHistory() {
        // Delete all images
        for item in history {
            cleanupFiles(for: item)
        }
        history.removeAll()
    }
    
    func updateItem(id: UUID, newContent: String) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        var item = history[index]
        // If editing an image, converting to text?
        // For V4, assuming we only edit text items. 
        // If it was image, prevent edit or convert? Let's assume Text edit only.
        if item.type == .text {
            // Note: If we edit the text content of a Rich Text item, we generally LOSE the rich text formatting
            // because the edited plain text no longer matches the stored RTF.
            // So we should verify if the user intended to strip formatting.
            // For now, we will create a NEW item with just the updated text, stripping legacy RTF paths to avoid out-of-sync data.
            let newItem = ClipboardItem(id: item.id, content: newContent, appBundleID: item.appBundleID, date: Date(), isPinned: item.isPinned, color: item.color, type: .text)
            history[index] = newItem
        }
    }
    
    func togglePin(id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        var item = history[index]
        item.isPinned.toggle()
        history[index] = item
    }
    
    func setColor(id: UUID, color: String?) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        var item = history[index]
        item.color = color
        history[index] = item
    }
    
    func deleteItem(id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        let item = history[index]
        cleanupFiles(for: item)
        history.remove(at: index)
    }
    
    // MARK: - Cloud Sync
    func startCloudSync() {
        NSUbiquitousKeyValueStore.default.synchronize()
        NotificationCenter.default.addObserver(self, selector: #selector(cloudDataChanged(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        loadFromCloud()
    }
    
    @objc func cloudDataChanged(_ notification: Notification) {
        Task { @MainActor in self.loadFromCloud() }
    }
    
    private func saveToCloud() {
        let pinned = history.filter { $0.isPinned }
        do { // Only sync text items to avoid large blobs
            let safePinned = pinned.filter { $0.type == .text } 
            let data = try JSONEncoder().encode(safePinned)
            NSUbiquitousKeyValueStore.default.set(data, forKey: "pinned_items")
            NSUbiquitousKeyValueStore.default.synchronize()
        } catch { print("Cloud Save Error: \(error)") }
    }
    
    private func loadFromCloud() {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: "pinned_items") else { return }
        do {
            let cloudPinned = try JSONDecoder().decode([ClipboardItem].self, from: data)
            for cloudItem in cloudPinned {
                if let index = history.firstIndex(where: { $0.id == cloudItem.id }) {
                    if !history[index].isPinned { history[index].isPinned = true }
                } else {
                    history.insert(cloudItem, at: 0)
                }
            }
        } catch { print("Cloud Load Error: \(error)") }
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(history)
            UserDefaults.standard.set(encoded, forKey: historyKey)
            saveToCloud()
        } catch { print("Failed to save history: \(error)") }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            self.history = decoded
        } catch { print("Failed to load history: \(error)") }
    }
}
