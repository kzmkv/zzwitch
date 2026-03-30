import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var debugMenuItem: NSMenuItem!
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    // Virtual key codes for digits 1–9 (US layout, but these are standard across layouts)
    static let digitKeyCodes: [Int64: Int] = [
        18: 0, // 1
        19: 1, // 2
        20: 2, // 3
        21: 3, // 4
        23: 4, // 5
        22: 5, // 6
        26: 6, // 7
        28: 7, // 8
        25: 8  // 9
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        waitForAccessibility()
    }

    func waitForAccessibility() {
        if AXIsProcessTrusted() {
            setupEventTap()
            return
        }
        // Prompt, then poll until granted — no restart needed
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.setupEventTap()
            }
        }
    }

    func makeStatusBarIcon() -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]
        let str = NSAttributedString(string: "W", attributes: attrs)
        let size = str.size()
        let image = NSImage(size: size, flipped: false) { _ in
            str.draw(at: .zero)
            return true
        }
        image.isTemplate = true
        return image
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = makeStatusBarIcon()

        let menu = NSMenu()

        debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugMenuItem.submenu = NSMenu()
        menu.addItem(debugMenuItem)

        menu.addItem(.separator())

        let reloadItem = NSMenuItem(title: "Reload Dock Apps", action: #selector(reloadDockApps), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu

        reloadDockApps()
    }

    @objc func reloadDockApps() {
        let debugMenu = NSMenu()
        let urls = dockAppURLs()
        for (i, url) in urls.prefix(9).enumerated() {
            let name = Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            let item = NSMenuItem(title: "\(i + 1): \(name)", action: #selector(debugApp(_:)), keyEquivalent: "")
            item.tag = i + 1
            item.target = self
            debugMenu.addItem(item)
        }
        debugMenuItem.submenu = debugMenu
    }

    func setupEventTap() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                // Return nil to consume (suppress) the event when we handle it
                if delegate.handleKeyEvent(event) { return nil }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap — Accessibility permission may be missing")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    @discardableResult
    func handleKeyEvent(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let watched: CGEventFlags = [.maskAlternate, .maskCommand, .maskShift, .maskControl, .maskSecondaryFn]
        guard flags.intersection(watched) == [.maskAlternate] else { return false }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let index = AppDelegate.digitKeyCodes[keyCode] else { return false }

        DispatchQueue.main.async { self.activateDockApp(at: index) }
        return true  // consumed
    }

    // MARK: - Dock

    func dockAppURLs() -> [URL] {
        CFPreferencesSynchronize("com.apple.dock" as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard let apps = CFPreferencesCopyAppValue(
            "persistent-apps" as CFString,
            "com.apple.dock" as CFString
        ) as? [[String: Any]] else { return [] }

        return apps.compactMap { entry -> URL? in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String else { return nil }
            return URL(string: urlString)
        }
    }

    func activateDockApp(at index: Int) {
        let urls = dockAppURLs()
        guard index < urls.count else { return }
        let appURL = urls[index]

        if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.standardized == appURL.standardized
        }) {
            if #available(macOS 14.0, *) {
                running.activate()
            } else {
                running.activate(options: [.activateIgnoringOtherApps])
            }
        } else {
            NSWorkspace.shared.openApplication(
                at: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, _ in }
        }
    }

    // MARK: - Debug

    @objc func debugApp(_ sender: NSMenuItem) { activateDockApp(at: sender.tag - 1) }

    // MARK: -

    func applicationWillTerminate(_ notification: Notification) {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
