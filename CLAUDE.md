# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build (Debug)
xcodebuild -scheme MouseLight -configuration Debug build

# Build (Release)
xcodebuild -scheme MouseLight -configuration Release build

# Clean
xcodebuild -scheme MouseLight clean

# Open in Xcode
open MouseLight.xcodeproj

# Built app location
~/Library/Developer/Xcode/DerivedData/MouseLight-*/Build/Products/Debug/MouseLight.app

# Archive for distribution
xcodebuild -scheme MouseLight -configuration Release archive -archivePath build/MouseLight.xcarchive
```

## Project Overview

**MouseLight** is a macOS menu bar utility for presentations that provides:
- Spotlight effect (dims screen, highlights cursor area)
- Click indicators (colored circles on mouse clicks)

| Property | Value |
|----------|-------|
| Platform | macOS 13.0+ |
| Language | Swift 5 |
| UI Framework | SwiftUI + AppKit |
| Bundle ID | com.mouselight.app |
| Sandbox | Disabled (requires Accessibility) |
| Dependencies | None (pure Apple frameworks) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MouseLightApp                            │
│                         (@main entry)                           │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AppDelegate                              │
│  - Creates status bar item                                      │
│  - Manages overlay windows                                      │
│  - Handles hotkey toggle                                        │
│  - Coordinates all components                                   │
└─────────────────────────────────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
┌──────────────┐ ┌─────────────┐ ┌──────────┐
│ EventMonitor │ │ Spotlight   │ │ Click    │
│              │ │ Overlay     │ │ Indicator│
│ - NSEvent    │ │ Window      │ │ Window   │
│   global     │ │ (per screen)│ │ (CVDisp- │
│   monitors   │ └─────────────┘ │  layLink)│
│ - Carbon     │        │        └──────────┘
│   Hotkey     │        ▼
└──────────────┘ ┌─────────────┐
                 │ SpotlightView│
                 │ (Core       │
                 │  Graphics)  │
                 └─────────────┘
```

## Source Code Structure

All source in `MouseLight/`:

| Directory | Key Files | Purpose |
|-----------|-----------|---------|
| `App/` | `AppDelegate.swift` | Main controller - window management, menu bar, event coordination |
| `App/` | `MouseLightApp.swift` | SwiftUI @main entry |
| `App/` | `Info.plist` | App metadata |
| `Models/` | `Settings.swift` | Singleton with @AppStorage properties |
| `Services/` | `EventMonitor.swift` | NSEvent global monitors (mouse), Carbon hotkey |
| `Services/` | `PermissionsManager.swift` | Accessibility permission checking |
| `Views/` | `SpotlightOverlayWindow.swift` | Multi-monitor spotlight - one NSWindow per screen |
| `Views/` | `SpotlightView.swift` | Core Graphics rendering - radial gradient with destinationOut blend |
| `Views/` | `CloudShape.swift` | Cloud shape path for spotlight |
| `Views/` | `ClickIndicatorWindow.swift` | Click visualization with CVDisplayLink animation |
| `Views/` | `PreferencesView.swift` | 3-tab preferences UI (Spotlight, Clicks, General) |
| `Views/` | `HotkeyRecorderView.swift` | Custom hotkey capture control |
| `Views/` | `AboutView.swift` | About window with feature documentation |
| `Views/` | `PermissionsWindowView.swift` | First-run onboarding flow |
| `Resources/` | `Assets.xcassets` | App and menu bar icons |

## Key Patterns

### Settings Access
```swift
let settings = AppSettings.shared
settings.spotlightRadius = 150.0  // Auto-persists to UserDefaults

// In SwiftUI views
@ObservedObject private var settings = AppSettings.shared
```

### Mouse Monitoring
Uses NSEvent global monitors instead of CGEventTap for reliable background app support:
```swift
// Global monitors work even when app is inactive (CGEventTap doesn't)
NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { event in
    let screenPoint = NSEvent.mouseLocation  // AppKit coordinates
    handleClick(at: screenPoint)
}
```

### Window Configuration
```swift
window.level = NSWindow.Level(rawValue: 1)  // Above normal, below menu bar
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
window.ignoresMouseEvents = true
```

### Carbon Hotkey
Global hotkeys use Carbon API (more reliable than NSEvent):
```swift
RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
```

## Common Tasks

### Add a New Setting
1. Add `@AppStorage` property to `Settings.swift`
2. Add UI control in `PreferencesView.swift` (appropriate tab)

### Add a New Overlay Effect
1. Create new NSWindow subclass in `Views/`
2. Set window properties: level, collectionBehavior, ignoresMouseEvents
3. Instantiate in `AppDelegate.setupOverlayWindows()`

### Add a New Preferences Tab
1. Add case to `PreferencesTab` enum in `PreferencesView.swift`
2. Create new tab View struct
3. Add to switch in `PreferencesView.body`

## Debugging

- **Accessibility**: `print("AXIsProcessTrusted:", AXIsProcessTrusted())`
- **Multi-monitor**: `NSScreen.screens[0]` is primary
- **Hotkey issues**: Requires running app, check for conflicts
- **Click indicators**: Use NSEvent global monitors (works when app inactive)

## Distribution

```bash
# Create DMG for distribution
mkdir -p build/dmg_staging
cp -R ~/Library/Developer/Xcode/DerivedData/MouseLight-*/Build/Products/Release/MouseLight.app build/dmg_staging/
ln -s /Applications build/dmg_staging/Applications
hdiutil create -volname "MouseLight" -srcfolder build/dmg_staging -ov -format UDZO build/MouseLight.dmg
rm -rf build/dmg_staging
```
