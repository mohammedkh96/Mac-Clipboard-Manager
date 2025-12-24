# Mac Clipboard Manager

<div align="center">

![App Icon](clipboard/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

**Advanced clipboard manager for macOS with Rich Text, Images, and Power User Features**

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## ✨ Features

### Core Functionality
- 🎯 **Smart Clipboard Monitoring** - Automatically captures text, images, and rich text
- 🔍 **Powerful Search** - Find any clipboard item instantly
- 📌 **Pin Important Items** - Keep frequently used items at the top
- 🎨 **Color Tags** - Organize items with visual color coding
- ⚡ **Global Hotkey** - Quick access with customizable keyboard shortcut (default: ⌘⇧V)

### Advanced Features
- 📝 **Rich Text Support** - Preserves formatting from Word, browsers, and editors
- 🖼️ **Image Support** - Copy and paste images with thumbnails
- 🔗 **Link Detection** - Auto-detects and filters URLs
- ✏️ **Text Editing** - Edit clipboard items before pasting
- 🎭 **Markdown Rendering** - View **bold**, *italic* text in the list

### Power User Tools
- ⚡ **Quick Actions**
  - Copy as Plain Text (strips formatting)
  - Transform text (UPPERCASE, lowercase, Title Case)
  - Remove line breaks
  - Open URLs directly
- 🎚️ **Customizable Settings**
  - History limit (50-500 items or unlimited)
  - Auto-delete old items (3/7/30 days)
  - Sound effects toggle
  - Launch at login
- 🌓 **Themes** - System, Light, or Dark mode
- ☁️ **Cloud Sync** - Sync pinned items across Macs via iCloud

## 📸 Screenshots

### Main Interface
The clean, modern interface with Liquid Glass design:
- Filter by type (All, Text, Images, Links)
- Search any item
- Pin, edit, color-tag, or delete items

### Settings Window
Comprehensive settings with:
- Appearance & Theme selection
- Behavior customization
- Storage management
- Keyboard shortcut configuration

## 🚀 Installation

### Download
1. Download the latest release from [Releases](https://github.com/YOUR_USERNAME/mac-clipboard-manager/releases)
2. Open the DMG file
3. Drag **Mac Clipboard Manager** to Applications
4. Launch the app

### First Launch
1. Grant **Accessibility permissions** when prompted (required for global hotkey)
2. The app runs in your menu bar
3. Press **⌘⇧V** or click the menu bar icon to access your clipboard history

## 🎮 Usage

### Quick Start
- **Open**: Press `⌘⇧V` (customizable in Settings)
- **Paste**: Click any item or press Enter
- **Search**: Start typing to filter
- **Pin**: Click the pin icon or right-click → Pin
- **Quick Actions**: Right-click any text item

### Keyboard Shortcuts
- `⌘⇧V` - Toggle clipboard window
- `↑/↓` - Navigate items
- `Enter` - Paste selected item
- `⌘P` - Toggle pin
- `⌘E` - Edit text item
- `Delete` - Delete item

### Filters
- **All** - Show everything
- **Text** - Text items only
- **Images** - Images only
- **Links** - Items containing URLs

## ⚙️ Settings

Access via gear icon (⚙️) in the app:

- **Appearance**: Choose theme (System/Light/Dark)
- **Startup**: Launch at login option
- **Behavior**: Sound effects, menu bar count, history limit
- **Storage**: Auto-delete old items
- **Keyboard**: Customize hotkey

## 🔧 Technical Details

- **Built with**: SwiftUI & AppKit
- **Requirements**: macOS 13.0 (Ventura) or later
- **Architecture**: Native Swift app
- **Storage**: Local (UserDefaults + File System) + iCloud sync for pins

## 📝 Version History

### v7.0.0 - Power User Features (Current)
- ✨ Quick Actions menu (transform, open URLs, copy plain text)
- ⚙️ Enhanced settings (history limit, sounds, menu bar)
- 🎨 Improved Settings window (resizable, better layout)

### v6.0.0 - Rich Text & Markdown
- 📝 Rich Text (RTF/HTML) support
- 🎨 Markdown rendering in list
- 📋 Rich text indicator icon

### v5.0.0 - Modernization
- 🌊 Liquid Glass UI
- 🚀 Launch at Login
- 🎨 Light mode improvements

### v4.0.0 - Media & Management
- 🖼️ Image support
- 🔍 Filter tabs (All/Text/Images/Links)
- 🗑️ Auto-delete old items
- ☁️ Cloud sync for pinned items

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Eng. Mohammed Ahmed**

- GitHub: [@mohammedkh96](https://github.com/mohammedkh96)
- Instagram: [@eng.mohammed.omar](https://www.instagram.com/eng.mohammed.omar/)
- Website: [eng-mohammed-omar.vercel.app](https://eng-mohammed-omar.vercel.app/)

## 🙏 Acknowledgments

- Built with ❤️ using Swift and SwiftUI
- Inspired by the need for a powerful, native macOS clipboard manager

---

<div align="center">

**If you find this useful, please star ⭐ this repo!**

</div>
