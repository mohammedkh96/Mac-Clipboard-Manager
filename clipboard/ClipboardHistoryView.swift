import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @ObservedObject var monitor: ClipboardMonitor
    var onPaste: (ClipboardItem) -> Void
    var onClose: () -> Void
    var onSettings: () -> Void
    
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    @State private var searchText = ""
    @State private var hoveredItemId: UUID?
    @State private var editingItem: ClipboardItem?
    @State private var showAboutSheet = false

    // MARK: - Computed Data
    var pinnedItems: [ClipboardItem] {
        processList(monitor.history.filter { $0.isPinned })
    }
    
    var recentItems: [ClipboardItem] {
        processList(monitor.history.filter { !$0.isPinned })
    }
    
    private func processList(_ items: [ClipboardItem]) -> [ClipboardItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            let contentMatch = item.content.localizedCaseInsensitiveContains(searchText)
            let appMatch = item.appBundleID?.localizedCaseInsensitiveContains(searchText) ?? false
            return contentMatch || appMatch
        }
    }
    
    var body: some View {
        ZStack {
            // Main View
            VStack(spacing: 0) {
                // Header
                HeaderView(monitor: monitor, onClose: onClose, onAbout: { showAboutSheet = true }, onSettings: onSettings, searchText: $searchText)
                
                Divider()
                    .overlay(Color(nsColor: .separatorColor))
                
                // Content List
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if !pinnedItems.isEmpty {
                            Section(header: SectionHeader(title: "Pinned", icon: "pin.fill")) {
                                ForEach(pinnedItems) { item in
                                    ClipboardItemRow(item: item, isHovered: hoveredItemId == item.id, onEdit: {
                                        editingItem = item
                                    }, onPin: {
                                        withAnimation { monitor.togglePin(id: item.id) }
                                    }, onDelete: {
                                        NSSound(named: "Trash")?.play()
                                        withAnimation { monitor.deleteItem(id: item.id) }
                                    }, onColor: { color in
                                        withAnimation { monitor.setColor(id: item.id, color: color) }
                                    })
                                    .onTapGesture {
                                        NSSound(named: "Pop")?.play()
                                        onPaste(item)
                                    }
                                    .onHover { hoveredItemId = $0 ? item.id : nil }
                                }
                            }
                        }
                        
                        if !recentItems.isEmpty {
                            Section(header: SectionHeader(title: "Recent", icon: "clock")) {
                                ForEach(recentItems) { item in
                                    ClipboardItemRow(item: item, isHovered: hoveredItemId == item.id, onEdit: {
                                        editingItem = item
                                    }, onPin: {
                                        withAnimation { monitor.togglePin(id: item.id) }
                                    }, onDelete: {
                                        NSSound(named: "Trash")?.play()
                                        withAnimation { monitor.deleteItem(id: item.id) }
                                    }, onColor: { color in
                                        withAnimation { monitor.setColor(id: item.id, color: color) }
                                    })
                                    .onTapGesture {
                                        NSSound(named: "Pop")?.play()
                                        onPaste(item)
                                    }
                                    .onHover { hoveredItemId = $0 ? item.id : nil }
                                }
                            }
                        }
                        
                        if pinnedItems.isEmpty && recentItems.isEmpty {
                            EmptyStateView()
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .blur(radius: editingItem != nil || showAboutSheet ? 5 : 0)
            .disabled(editingItem != nil || showAboutSheet)
            
            // Edit Overlay
            if let itemToEdit = editingItem {
                EditOverlay(item: itemToEdit, onSave: { newContent in
                    monitor.updateItem(id: itemToEdit.id, newContent: newContent)
                    editingItem = nil
                }, onCancel: {
                    editingItem = nil
                })
            }
            
            // About Overlay
            if showAboutSheet {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { showAboutSheet = false }
                AboutView(onClose: { showAboutSheet = false })
                    .shadow(radius: 20)
            }
        }
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow).ignoresSafeArea())
        .frame(width: 380, height: 600)
        .preferredColorScheme(appTheme == "light" ? .light : (appTheme == "dark" ? .dark : nil))
    }
}

// MARK: - Components

struct HeaderView: View {
    @ObservedObject var monitor: ClipboardMonitor
    var onClose: () -> Void
    var onAbout: () -> Void
    var onSettings: () -> Void
    @Binding var searchText: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onAbout) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("About")
                
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                Text("Clipboard")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { monitor.clearHistory() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear All")
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 14)
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                TextField("Search history & apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5)) // Slightly transparent
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
        .padding(.bottom, 10)
        .background(VisualEffectBlur(material: .headerView, blendingMode: .withinWindow).ignoresSafeArea())
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)) // Stick header bg
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    var onEdit: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void
    var onColor: (String?) -> Void
    
    // Helpers for coloring
    var itemColor: Color {
        switch item.color {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .clear
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Color Indicator Strip
            if item.color != nil {
                Rectangle()
                    .fill(itemColor)
                    .frame(width: 4)
            } else {
                Spacer().frame(width: 4)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(item.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if let bundleID = item.appBundleID {
                        Label(bundleID.components(separatedBy: ".").last?.capitalized ?? "App", systemImage: "app")
                            .font(.system(size: 10))
                    }
                    
                    Text(item.date, style: .time)
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            
            Spacer()
            
            // Actions (Hover)
            if isHovered || item.isPinned {
                HStack(spacing: 4) {
                    // Pin Button
                    Button(action: onPin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundColor(item.isPinned ? .accentColor : .secondary)
                            .padding(4)
                            .background(Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    
                    if isHovered {
                        // Edit Button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(4)
                                .background(Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .help("Edit")
                        
                        // Delete Button (New)
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(4)
                                .background(Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
                .padding(.trailing, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onDrag {
            return NSItemProvider(object: item.content as NSString)
        }
        // Context Menu for extra actions
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") { onPin() }
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
            Divider()
            Text("Color Tag")
            Button("None") { onColor(nil) }
            Button("Red") { onColor("red") }
            Button("Orange") { onColor("orange") }
            Button("Green") { onColor("green") }
            Button("Blue") { onColor("blue") }
            Button("Purple") { onColor("purple") }
        }
    }
}

// MARK: - Edit Overlay
struct EditOverlay: View {
    let item: ClipboardItem
    var onSave: (String) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            EditItemView(item: item, onSave: onSave, onCancel: onCancel)
                .frame(width: 320, height: 420)
                .background(VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow))
                .cornerRadius(16)
                .shadow(radius: 20)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Clipboard Items")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Legacy / Helper
// (Assuming EditItemView and VisualEffectBlur remain as previously defined, or I can redefine them if you want a clean file. 
// I will include VisualEffectBlur here for safety, but assume EditItemView is fine to reuse or I can include it below to be safe)

// Re-including EditItemView to update style if needed, or just standard.
// For Conciseness, I will assume EditItemView exists in file or append it. 
// ACTUALLY, I'm replacing the whole file so I MUST include EditItemView.

struct EditItemView: View {
    let item: ClipboardItem
    var onSave: (String) -> Void
    var onCancel: () -> Void
    
    @State private var content: String
    @State private var isPreviewMode: Bool = false
    
    init(item: ClipboardItem, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _content = State(initialValue: item.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isPreviewMode ? "Preview" : "Edit")
                    .font(.headline)
                Spacer()
                Button(isPreviewMode ? "Edit" : "Preview") {
                    withAnimation { isPreviewMode.toggle() }
                }
                .font(.caption)
            }
            .padding()
            
            Divider()
            
            if isPreviewMode {
                ScrollView {
                    Text(.init(content))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                TextEditor(text: $content)
                    .font(.body)
                    .padding(8)
                    .background(Color.clear)
            }
            
            Divider()
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave(content) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}



struct AboutView: View {
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
                .shadow(radius: 10)
            
            VStack(spacing: 5) {
                Text("Mac Clipboard Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Version 2.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(width: 200)
            
            VStack(spacing: 8) {
                Text("Developed by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Haji Salam")
                    .font(.headline)
            }
            
            Text("© 2025 Haji Salam. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.tertiaryLabel)
                .padding(.top, 10)
            
            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
            .padding(.top, 20)
        }
        .padding(30)
        .frame(width: 300)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow))
        .cornerRadius(20)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material { nsView.material = material }
        if nsView.blendingMode != blendingMode { nsView.blendingMode = blendingMode }
        if nsView.state != .active { nsView.state = .active }
    }
}

extension Color {
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
}
