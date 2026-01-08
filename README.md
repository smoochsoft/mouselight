# MouseLight

A macOS menu bar app for presentations and screencasts. Highlights your cursor with a spotlight effect and visualizes mouse clicks.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Spotlight Effect** - Dims the screen with a customizable spotlight following your cursor
- **Multiple Shapes** - Circle, Square, Triangle, Star, Trapezoid, or Cloud
- **Click Indicators** - Shows expanding colored circles for left, right, and middle clicks
- **Multi-Monitor Support** - Works across all connected displays
- **Customizable** - Adjust sizes, colors, blur, animations, and hotkeys

## Installation

### From DMG
1. Download `MouseLight.dmg` from Releases
2. Open the DMG and drag MouseLight to Applications
3. Launch MouseLight from Applications
4. Grant Accessibility permission when prompted

### From Source
```bash
git clone https://github.com/yourusername/mouselight.git
cd mouselight
xcodebuild -scheme MouseLight -configuration Release build
```

## Usage

### Quick Start
1. Launch MouseLight (appears in menu bar)
2. Press `Cmd+Shift+M` to toggle the spotlight
3. Press `Escape` to deactivate the spotlight
4. Click the menu bar icon for options

### Keyboard Shortcuts
| Action | Default Shortcut |
|--------|-----------------|
| Toggle Spotlight | `Cmd+Shift+M` |
| Deactivate Spotlight | `Escape` |
| Open Preferences | Click menu bar icon > Preferences |

### Preferences

Access via menu bar icon > **Preferences...**

**Spotlight Tab**
- Toggle hotkey (customizable)
- Auto-deactivate timer
- Shape selection (Circle, Square, Triangle, Star, Trapezoid, Cloud)
- Size, edge blur, and dim opacity
- Zoom animation toggle

**Clicks Tab**
- Enable/disable click indicators
- Mode: Always On or With Spotlight only
- Customize click color, size, and animation duration

**General Tab**
- Launch at login
- Accessibility permission status

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission (required for mouse/keyboard monitoring)

## Permissions

MouseLight requires **Accessibility** permission to:
- Monitor mouse movements and clicks
- Register global hotkeys

The app will guide you through granting permission on first launch.

## Troubleshooting

### Spotlight not following cursor
1. Check System Settings > Privacy & Security > Accessibility
2. Ensure MouseLight is listed and enabled
3. Try removing and re-adding the permission

### Hotkey not working
1. Make sure no other app is using the same hotkey
2. Try setting a different hotkey in Preferences

### Click indicators not appearing
1. Check if click indicators are enabled in Preferences > Clicks
2. If mode is "With Spotlight", ensure spotlight is active first

### Menu bar icon not visible
- Check if you have too many menu bar items
- Try using Bartender or similar to manage menu bar space

## Building from Source

### Requirements
- Xcode 15.0+
- macOS 13.0+ SDK

### Build Commands
```bash
# Debug build
xcodebuild -scheme MouseLight -configuration Debug build

# Release build
xcodebuild -scheme MouseLight -configuration Release build

# Create archive
xcodebuild -scheme MouseLight -configuration Release archive -archivePath build/MouseLight.xcarchive
```

### Project Structure
```
MouseLight/
├── App/
│   ├── AppDelegate.swift       # Main app controller
│   ├── MouseLightApp.swift     # SwiftUI app entry
│   ├── Info.plist              # App metadata
│   └── MouseLight.entitlements
├── Models/
│   └── Settings.swift          # App settings (@AppStorage)
├── Services/
│   ├── EventMonitor.swift      # Mouse/keyboard event capture
│   └── PermissionsManager.swift
├── Views/
│   ├── SpotlightOverlayWindow.swift  # Multi-monitor spotlight
│   ├── SpotlightView.swift           # Spotlight rendering
│   ├── CloudShape.swift              # Cloud shape path
│   ├── ClickIndicatorWindow.swift    # Click visualization
│   ├── PreferencesView.swift         # Settings UI (3 tabs)
│   ├── HotkeyRecorderView.swift      # Hotkey capture
│   ├── AboutView.swift               # About window
│   └── PermissionsWindowView.swift   # Onboarding
└── Resources/
    └── Assets.xcassets         # App and menu bar icons
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For AI assistants: See `CLAUDE.md` for detailed technical documentation.
