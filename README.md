# zzwitch

A minimal macOS menu bar app that switches between your pinned Dock apps using keyboard shortcuts.

## Usage

Press **Option+1–9** to activate or launch the corresponding app from your Dock (left to right).
Press **Option+0** to show or hide a centered overlay listing the current hotkeys and mapped app names.

- If the app is already running, it is brought to the front.
- If it is not running, it is launched.

The menu bar icon (**W**) provides:

- **Dock Apps** — submenu listing your pinned Dock apps with their Option+1–9 shortcuts on the right; click an app to activate or launch it
- **Show/Hide Hotkeys Overlay** — toggles the centered shortcut reference window
- **Reload Dock Apps** — re-reads the Dock after you add, remove, or reorder pinned apps
- **Run on startup** — check to launch zzwitch automatically when you log in; uncheck to disable. On macOS 13+, a dash means approval is pending in System Settings → General → Login Items. On macOS 12, this uses a per-user LaunchAgent.
- **Quit**

## Build

Requires Xcode Command Line Tools (`xcode-select --install`).

```sh
chmod +x build.sh
./build.sh
open zzwitch.app
```

On first launch, macOS will prompt for **Accessibility** permission. Grant it in **System Settings → Privacy & Security → Accessibility** — no restart needed, hotkeys activate immediately.

> **Note:** Each rebuild resets the Accessibility permission entry. You will be prompted once per build.

## Files

| File | Purpose |
|---|---|
| `zzwitch.swift` | Main application source |
| `GenerateIcon.swift` | Generates the `.icns` app icon at build time |
| `Info.plist` | App bundle metadata |
| `build.sh` | Build script — compiles, bundles, signs |
