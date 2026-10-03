import Cocoa
import ServiceManagement

final class ShortcutOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Dock Hotkeys")
    private let subtitleLabel = NSTextField(labelWithString: "Press Option+1-9 to switch apps")
    private let rowsStack = NSStackView()
    private let footerLabel = NSTextField(labelWithString: "Option+0 toggles this panel")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func update(appNames: [String]) {
        rowsStack.arrangedSubviews.forEach { view in
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if appNames.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No pinned Dock apps were found.")
            emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
            emptyLabel.textColor = NSColor.white.withAlphaComponent(0.82)
            rowsStack.addArrangedSubview(emptyLabel)
            return
        }

        for (offset, appName) in appNames.enumerated() {
            rowsStack.addArrangedSubview(makeRow(index: offset + 1, appName: appName))
        }
    }

    private func setupUI() {
        let effectView = NSVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .hudWindow
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 24
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        effectView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.94).cgColor
        addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16

        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.7)

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 10

        footerLabel.font = .systemFont(ofSize: 13, weight: .medium)
        footerLabel.textColor = NSColor.white.withAlphaComponent(0.6)

        [titleLabel, subtitleLabel, rowsStack, footerLabel].forEach(contentStack.addArrangedSubview)
        effectView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -24),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    private func makeRow(index: Int, appName: String) -> NSView {
        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 12

        let badge = makeBadge(text: "Option+\(index)")
        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        rowStack.addArrangedSubview(badge)
        rowStack.addArrangedSubview(nameLabel)
        return rowStack
    }

    private func makeBadge(text: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 9
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.55, blue: 1.0, alpha: 0.9).cgColor

        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 14, weight: .bold)
        label.textColor = .white

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])

        return container
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var dockAppsMenuItem: NSMenuItem!
    var overlayMenuItem: NSMenuItem!
    var startupMenuItem: NSMenuItem!
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var shortcutOverlayPanel: NSPanel?
    var shortcutOverlayView: ShortcutOverlayView?

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
    static let overlayToggleKeyCode: Int64 = 29 // 0

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
        menu.delegate = self

        dockAppsMenuItem = NSMenuItem(title: "Dock Apps", action: nil, keyEquivalent: "")
        dockAppsMenuItem.submenu = NSMenu()
        menu.addItem(dockAppsMenuItem)

        menu.addItem(.separator())

        overlayMenuItem = NSMenuItem(title: "Show Hotkeys Overlay", action: #selector(toggleShortcutOverlay), keyEquivalent: "")
        overlayMenuItem.target = self
        menu.addItem(overlayMenuItem)

        let reloadItem = NSMenuItem(title: "Reload Dock Apps", action: #selector(reloadDockApps), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())
        startupMenuItem = NSMenuItem(title: "Run on startup", action: #selector(toggleRunOnStartup), keyEquivalent: "")
        startupMenuItem.target = self
        menu.addItem(startupMenuItem)
        updateStartupMenuItem()

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu

        reloadDockApps()
    }

    // MARK: - Run on startup

    private var legacyStartupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.local.zzwitch.startup.plist")
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateStartupMenuItem()
    }

    private func updateStartupMenuItem() {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                startupMenuItem.state = .on
            case .requiresApproval:
                startupMenuItem.state = .mixed
            default:
                startupMenuItem.state = .off
            }
        } else {
            startupMenuItem.state = FileManager.default.fileExists(atPath: legacyStartupURL.path) ? .on : .off
        }
    }

    @objc func toggleRunOnStartup() {
        defer { updateStartupMenuItem() }

        guard Bundle.main.bundleURL.pathExtension == "app" else {
            showStartupError("Run zzwitch from its .app bundle to configure startup.")
            return
        }

        do {
            if #available(macOS 13.0, *) {
                let service = SMAppService.mainApp
                if service.status == .enabled || service.status == .requiresApproval {
                    try service.unregister()
                } else {
                    try service.register()
                    if service.status == .requiresApproval {
                        requestStartupApproval()
                    }
                }
            } else {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: legacyStartupURL.path) {
                    try fileManager.removeItem(at: legacyStartupURL)
                } else {
                    let propertyList: [String: Any] = [
                        "Label": "com.local.zzwitch.startup",
                        "ProgramArguments": ["/usr/bin/open", "-g", Bundle.main.bundleURL.path],
                        "RunAtLoad": true
                    ]
                    let data = try PropertyListSerialization.data(fromPropertyList: propertyList, format: .xml, options: 0)
                    try fileManager.createDirectory(at: legacyStartupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: legacyStartupURL, options: .atomic)
                }
            }
        } catch {
            if #available(macOS 13.0, *), SMAppService.mainApp.status == .requiresApproval {
                requestStartupApproval()
            } else {
                showStartupError(error.localizedDescription)
            }
        }
    }

    @available(macOS 13.0, *)
    private func requestStartupApproval() {
        let alert = NSAlert()
        alert.messageText = "Allow zzwitch to run on startup"
        alert.informativeText = "Enable zzwitch in System Settings → General → Login Items. A dash in the menu means approval is pending."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func showStartupError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not change startup settings"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func reloadDockApps() {
        let dockAppsMenu = NSMenu()
        let urls = dockAppURLs()
        for (i, url) in urls.prefix(9).enumerated() {
            let name = Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            let item = NSMenuItem(title: name, action: #selector(selectDockApp(_:)), keyEquivalent: "\(i + 1)")
            item.keyEquivalentModifierMask = [.option]
            item.tag = i + 1
            item.target = self
            dockAppsMenu.addItem(item)
        }
        dockAppsMenuItem.submenu = dockAppsMenu
        refreshShortcutOverlay()
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
        if keyCode == AppDelegate.overlayToggleKeyCode {
            DispatchQueue.main.async { self.toggleShortcutOverlay() }
            return true
        }

        guard let index = AppDelegate.digitKeyCodes[keyCode] else { return false }

        DispatchQueue.main.async { self.activateDockApp(at: index) }
        return true  // consumed
    }

    // MARK: - Overlay

    @objc func toggleShortcutOverlay() {
        ensureShortcutOverlay()

        guard let panel = shortcutOverlayPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            refreshShortcutOverlay()
            centerOverlay(panel)
            panel.orderFrontRegardless()
        }

        updateOverlayMenuTitle()
    }

    func ensureShortcutOverlay() {
        guard shortcutOverlayPanel == nil else { return }

        let overlayView = ShortcutOverlayView(frame: NSRect(x: 0, y: 0, width: 440, height: 320))
        overlayView.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.contentView = overlayView

        shortcutOverlayPanel = panel
        shortcutOverlayView = overlayView
        refreshShortcutOverlay()
    }

    func refreshShortcutOverlay() {
        let appNames = dockAppURLs().prefix(9).map { url in
            Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
        }

        shortcutOverlayView?.update(appNames: Array(appNames))
        resizeOverlayToFit()
        updateOverlayMenuTitle()
    }

    func resizeOverlayToFit() {
        guard let panel = shortcutOverlayPanel, let contentView = shortcutOverlayView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        let size = NSSize(width: max(440, fittingSize.width), height: max(220, fittingSize.height))
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: false)
    }

    func centerOverlay(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - (panel.frame.width / 2),
            y: visibleFrame.midY - (panel.frame.height / 2)
        )
        panel.setFrameOrigin(origin)
    }

    func updateOverlayMenuTitle() {
        overlayMenuItem?.title = shortcutOverlayPanel?.isVisible == true
            ? "Hide Hotkeys Overlay"
            : "Show Hotkeys Overlay"
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

    // MARK: - Dock menu

    @objc func selectDockApp(_ sender: NSMenuItem) { activateDockApp(at: sender.tag - 1) }

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
