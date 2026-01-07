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
- Keystroke display (shows keyboard input on screen)

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
         │              │              │              │
         ▼              ▼              ▼              ▼
┌──────────────┐ ┌─────────────┐ ┌──────────┐ ┌─────────────┐
│ EventMonitor │ │ Spotlight   │ │ Click    │ │ Keystroke   │
│              │ │ Overlay     │ │ Indicator│ │ Overlay     │
│ - CGEventTap │ │ Window      │ │ Window   │ │ Window      │
│ - NSEvent    │ │ (per screen)│ │          │ │             │
│ - Carbon     │ └─────────────┘ └──────────┘ └─────────────┘
│   Hotkey     │        │
└──────────────┘        ▼
                 ┌─────────────┐
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
| `App/` | `Info.plist` | LSUIElement=true (menu bar only) |
| `Models/` | `Settings.swift` | Singleton with ~30 @AppStorage properties |
| `Services/` | `EventMonitor.swift` | CGEventTap (mouse), NSEvent (keyboard), Carbon hotkey |
| `Services/` | `PermissionsManager.swift` | Accessibility permission checking |
| `Views/` | `SpotlightOverlayWindow.swift` | Multi-monitor spotlight - one NSWindow per screen |
| `Views/` | `SpotlightView.swift` | Core Graphics rendering - radial gradient with destinationOut blend |
| `Views/` | `ClickIndicatorWindow.swift` | Click visualization with expanding circle animation |
| `Views/` | `KeystrokeOverlayWindow.swift` | SwiftUI-based keystroke display |
| `Views/` | `PreferencesView.swift` | 4-tab preferences UI |
| `Views/` | `HotkeyRecorderView.swift` | Custom hotkey capture control |
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

### Coordinate Systems (Critical)
CGEvent and AppKit use different origins:
```swift
// CGEvent: Top-left origin, Y increases DOWN
// AppKit: Bottom-left origin, Y increases UP
guard let primaryScreen = NSScreen.screens.first else { return }
let appKitY = primaryScreen.frame.maxY - cgEventY
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
- **Event tap fails**: Returns nil without Accessibility permission
- **Multi-monitor**: `NSScreen.screens[0]` is primary
- **Hotkey issues**: Requires running app, check for conflicts
