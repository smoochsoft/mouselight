# MouseLight

A macOS menu bar app for presentations and screencasts. Highlights your cursor with a spotlight effect, visualizes mouse clicks, and displays keystrokes on screen.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Spotlight Effect** - Dims the screen with a circular spotlight following your cursor
- **Click Indicators** - Shows expanding colored circles for left, right, and middle clicks
- **Keystroke Display** - Displays keyboard shortcuts and keystrokes on screen
- **Multi-Monitor Support** - Works across all connected displays
- **Customizable** - Adjust sizes, colors, animations, and hotkeys

## Installation

### From DMG
1. Download `MouseLight.dmg` from Releases
2. Open the DMG and drag MouseLight to Applications
3. Launch MouseLight from Applications
4. Grant Accessibility permission when prompted

### From Source
```bash
git clone https://github.com/yourusername/mouselight.git
cd mouselight/MouseLight
xcodebuild -scheme MouseLight -configuration Release build
```

## Usage

### Quick Start
1. Launch MouseLight (appears in menu bar)
2. Press `Cmd+Shift+M` to toggle the spotlight
3. Click the menu bar icon for options

### Keyboard Shortcuts
| Action | Default Shortcut |
|--------|-----------------|
| Toggle Spotlight | `Cmd+Shift+M` |
| Open Preferences | Click menu bar icon → Preferences |

### Preferences

Access via menu bar icon → **Preferences...**

**Spotlight Tab**
- Toggle hotkey (customizable)
- Auto-deactivate timer
- Circle radius, blur, and dim opacity
- Zoom animation toggle

**Clicks Tab**
- Enable/disable click indicators
- Mode: Always On or With Spotlight only
- Customize colors for left/right/middle click
- Click sound with volume control

**Keystrokes Tab**
- Enable/disable keystroke display
- Mode: Always On or With Spotlight only
- Filter: All keys or Shortcuts only
- Font size and display duration
- Select which monitor to display on

**General Tab**
- Launch at login
- Accessibility permission status

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission (required for mouse/keyboard monitoring)

## Permissions

MouseLight requires **Accessibility** permission to:
- Monitor mouse movements and clicks
- Capture keyboard input for display
- Register global hotkeys

The app will guide you through granting permission on first launch.

## Troubleshooting

### Spotlight not following cursor
1. Check System Settings → Privacy & Security → Accessibility
2. Ensure MouseLight is listed and enabled
3. Try removing and re-adding the permission

### Hotkey not working
1. Make sure no other app is using the same hotkey
2. Try setting a different hotkey in Preferences

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
├── App/                    # App entry point and configuration
│   ├── AppDelegate.swift   # Main app controller
│   ├── MouseLightApp.swift # SwiftUI app entry
│   ├── Info.plist          # App metadata
│   └── MouseLight.entitlements
├── Models/
│   └── Settings.swift      # App settings (@AppStorage)
├── Services/
│   ├── EventMonitor.swift  # Mouse/keyboard event capture
│   └── PermissionsManager.swift
├── Views/
│   ├── SpotlightOverlayWindow.swift  # Multi-monitor spotlight
│   ├── SpotlightView.swift           # Spotlight rendering
│   ├── ClickIndicatorWindow.swift    # Click visualization
│   ├── KeystrokeOverlayWindow.swift  # Keystroke display
│   ├── PreferencesView.swift         # Settings UI
│   ├── HotkeyRecorderView.swift      # Hotkey capture
│   └── PermissionsWindowView.swift   # Onboarding
└── Resources/
    └── Assets.xcassets     # App and menu bar icons
```

## License

MIT License - see LICENSE file for details.

## Credits

Inspired by [Mouseposé](https://boinx.com/mousepose/) by Boinx Software.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For AI assistants: See `CLAUDE.md` for detailed technical documentation.
