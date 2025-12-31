import Cocoa

class ClickableView: NSView {
    var clickHandler: (() -> Void)?
    var windowOriginOnMouseDown: NSPoint?

    override func mouseDown(with event: NSEvent) {
        windowOriginOnMouseDown = window?.frame.origin
    }

    override func mouseUp(with event: NSEvent) {
        // Only trigger click if window didn't move (wasn't dragged)
        if let originalOrigin = windowOriginOnMouseDown,
           let currentOrigin = window?.frame.origin {
            let distance = hypot(currentOrigin.x - originalOrigin.x, currentOrigin.y - originalOrigin.y)
            if distance < 1 {  // Window didn't move = it's a click
                clickHandler?()
            }
        }
        windowOriginOnMouseDown = nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusLabel: NSTextField!
    var logView: NSTextView!
    var timer: Timer?
    var hasDevice = false
    var consoleButton: NSButton!
    var consoleWindow: NSWindow?
    var consoleTextView: NSTextView!
    var logStreamProcess: Process?
    var scrcpyProcess: Process?
    var isSmallMode = false
    let fullSize = NSSize(width: 390, height: 894)  // Extra 50pt for toolbar
    let smallSize = NSSize(width: 195, height: 447)
    let toolbarHeight: CGFloat = 50
    let packageName = "com.miso.noobtest"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar
        setupMenuBar()

        // Clean up on quit
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: fullSize.width, height: fullSize.height),
            styleMask: [.borderless, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .normal

        // Replace content view with clickable view
        let clickableView = ClickableView(frame: window.contentView!.bounds)
        clickableView.clickHandler = { [weak self] in
            self?.toggleWindowSize()
        }
        window.contentView = clickableView

        // Add rounded background with Android-style colors (darker, more rectangular)
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        window.contentView?.layer?.cornerRadius = 30  // Slightly less rounded than iPhone
        window.contentView?.layer?.masksToBounds = true
        window.contentView?.layer?.borderWidth = 6
        window.contentView?.layer?.borderColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor

        // Create toolbar area at the top (above where scrcpy will be)
        let toolbarView = NSView(frame: NSRect(x: 0, y: fullSize.height - toolbarHeight, width: fullSize.width, height: toolbarHeight))
        toolbarView.wantsLayer = true
        toolbarView.layer?.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0).cgColor
        window.contentView?.addSubview(toolbarView)

        // Create status label in toolbar
        statusLabel = NSTextField(frame: NSRect(x: 10, y: 10, width: 280, height: 30))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.textColor = .white
        statusLabel.alignment = .left
        statusLabel.stringValue = "Checking for device..."
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        toolbarView.addSubview(statusLabel)

        // Create log view
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 10, width: 370, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        logView = NSTextView(frame: scrollView.bounds)
        logView.isEditable = false
        logView.font = NSFont(name: "Menlo", size: 10)
        logView.textColor = .lightGray
        logView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        scrollView.documentView = logView
        window.contentView?.addSubview(scrollView)

        // Create console button on the right edge
        setupConsoleButton()

        window.makeKeyAndOrderFront(nil)

        // Track window movement to reposition scrcpy
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )

        log("Android Screen Capture started")

        // Start checking for devices
        checkForDevice()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForDevice()
        }
    }

    func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(NSMenuItem(title: "About Android Screen Cap", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Android Screen Cap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Window menu
        let windowMenuItem = NSMenuItem()
        windowMenuItem.title = "Window"
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))

        NSApplication.shared.mainMenu = mainMenu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Android Screen Cap"
        alert.informativeText = "Version 1.0\n\nMirrors your Android screen using scrcpy when connected via USB.\n\nRequires: scrcpy, adb"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func setupConsoleButton() {
        // Create a small rounded square button in the toolbar area (top right)
        let buttonSize: CGFloat = 36
        let buttonX: CGFloat = fullSize.width - buttonSize - 12
        let buttonY: CGFloat = fullSize.height - toolbarHeight + (toolbarHeight - buttonSize) / 2
        consoleButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize))
        consoleButton.title = ""
        consoleButton.bezelStyle = .rounded
        consoleButton.setButtonType(.pushOnPushOff)
        consoleButton.target = self
        consoleButton.action = #selector(toggleConsole)

        // Style as a small rounded square - Android green accent
        consoleButton.wantsLayer = true
        consoleButton.layer?.backgroundColor = NSColor(red: 0.0, green: 0.6, blue: 0.4, alpha: 0.95).cgColor
        consoleButton.layer?.cornerRadius = 8
        consoleButton.layer?.borderWidth = 0

        // Add chevron label centered in button
        let label = NSTextField(frame: NSRect(x: 0, y: -9, width: buttonSize, height: buttonSize))
        label.stringValue = ">"
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .white
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        consoleButton.addSubview(label)

        window.contentView?.addSubview(consoleButton)
    }

    @objc func toggleConsole() {
        if consoleWindow == nil {
            setupConsoleWindow()
        }

        if consoleWindow!.isVisible {
            consoleWindow?.orderOut(nil)
            stopLogStream()
        } else {
            // Position console to the right of the main window
            let mainFrame = window.frame
            let consoleFrame = NSRect(
                x: mainFrame.maxX + 10,
                y: mainFrame.minY,
                width: 500,
                height: mainFrame.height
            )
            consoleWindow?.setFrame(consoleFrame, display: true)
            consoleWindow?.makeKeyAndOrderFront(nil)

            // Start log stream
            startLogStream()
        }
    }

    func setupConsoleWindow() {
        consoleWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 844),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        consoleWindow?.title = "Android Console"
        consoleWindow?.isReleasedWhenClosed = false
        consoleWindow?.level = .normal

        // Create text view for console
        let scrollView = NSScrollView(frame: consoleWindow!.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        consoleTextView = NSTextView(frame: scrollView.bounds)
        consoleTextView.isEditable = false
        consoleTextView.font = NSFont(name: "Menlo", size: 11)
        consoleTextView.textColor = NSColor(red: 0.0, green: 0.9, blue: 0.4, alpha: 1.0)  // Android green
        consoleTextView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        consoleTextView.autoresizingMask = [.width, .height]

        scrollView.documentView = consoleTextView
        consoleWindow?.contentView?.addSubview(scrollView)
    }

    func startLogStream() {
        consoleTextView.string = "Starting log stream for \(packageName)...\n\n"

        // Stop any existing process
        stopLogStream()

        // Clear logcat buffer first
        let clearProcess = Process()
        clearProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        clearProcess.arguments = ["adb", "logcat", "-c"]
        try? clearProcess.run()
        clearProcess.waitUntilExit()

        // Create new process to run adb logcat
        logStreamProcess = Process()
        logStreamProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        logStreamProcess?.arguments = ["adb", "logcat", "-v", "brief"]

        // Set up pipes for output
        let outputPipe = Pipe()
        logStreamProcess?.standardOutput = outputPipe
        logStreamProcess?.standardError = outputPipe

        // Read output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }

            let data = handle.availableData
            guard data.count > 0 else { return }

            if let output = String(data: data, encoding: .utf8) {
                // Filter for app logs with [APP] prefix
                let lines = output.components(separatedBy: .newlines)

                for line in lines {
                    // Look for [APP] prefix in our package logs
                    if line.contains("[APP]") && (line.contains("MisoLogger") || line.contains(self.packageName)) {
                        // Parse logcat line (format: "I/Tag(PID): message")
                        let pattern = #"([VDIWEF])/([^(]+)\(\s*\d+\):\s*(.+)"#
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                           let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {

                            if let levelRange = Range(match.range(at: 1), in: line),
                               let messageRange = Range(match.range(at: 3), in: line) {
                                let level = String(line[levelRange])
                                var message = String(line[messageRange])

                                // Strip [APP] prefix from message
                                message = message.replacingOccurrences(of: "[APP] ", with: "")

                                // Map level to name
                                let levelMap = ["V": "VERBOSE", "D": "DEBUG", "I": "INFO",
                                              "W": "WARN", "E": "ERROR", "F": "FATAL"]
                                let levelName = levelMap[level] ?? level

                                let timestamp = DateFormatter.localizedString(
                                    from: Date(),
                                    dateStyle: .none,
                                    timeStyle: .medium
                                )

                                let logLine = "\(timestamp) [\(levelName)] \(message)\n"

                                DispatchQueue.main.async {
                                    self.consoleTextView.string += logLine
                                    self.consoleTextView.scrollToEndOfDocument(nil)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Start the process
        do {
            try logStreamProcess?.run()
            DispatchQueue.main.async {
                self.consoleTextView.string += "Log stream started successfully\n\n"
            }
        } catch {
            DispatchQueue.main.async {
                self.consoleTextView.string = "Failed to start log stream: \(error.localizedDescription)\n"
            }
        }
    }

    func stopLogStream() {
        if let process = logStreamProcess, process.isRunning {
            process.terminate()
            logStreamProcess = nil
        }
    }

    @objc func applicationWillTerminate(_ notification: Notification) {
        stopLogStream()
        stopScrcpy()
    }

    func checkForDevice() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["adb", "devices"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                // Skip header line, look for devices
                let devices = lines.dropFirst().filter { line in
                    line.contains("device") && !line.contains("devices")
                }

                if let deviceLine = devices.first {
                    let deviceId = deviceLine.components(separatedBy: .whitespaces).first ?? "Unknown"

                    if !hasDevice {
                        hasDevice = true
                        log("Device connected: \(deviceId)")
                        statusLabel.stringValue = "Android: \(deviceId)"
                        startScrcpy()
                    }
                } else {
                    if hasDevice {
                        hasDevice = false
                        stopScrcpy()
                        log("Device disconnected")
                    }
                    statusLabel.stringValue = "No device found"
                }
            }
        } catch {
            statusLabel.stringValue = "Error: \(error.localizedDescription)"
        }
    }

    func startScrcpy() {
        log("Starting scrcpy...")

        // Position scrcpy window below the toolbar
        let windowFrame = window.frame

        // Calculate scrcpy window position - below toolbar, inside border
        let borderWidth: CGFloat = 6
        let scrcpyX = Int(windowFrame.origin.x + borderWidth)
        // Y position: account for toolbar at top (macOS coordinates are bottom-up)
        let scrcpyY = Int(NSScreen.main!.frame.height - windowFrame.origin.y - windowFrame.height + borderWidth + toolbarHeight)

        // Calculate size accounting for border and toolbar
        let scrcpyWidth = Int(windowFrame.width - borderWidth * 2)
        let scrcpyHeight = Int(windowFrame.height - borderWidth * 2 - toolbarHeight)

        scrcpyProcess = Process()
        scrcpyProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        scrcpyProcess?.arguments = [
            "scrcpy",
            "--window-borderless",
            "--window-x", String(scrcpyX),
            "--window-y", String(scrcpyY),
            "--window-width", String(scrcpyWidth),
            "--window-height", String(scrcpyHeight),
            "--stay-awake"
        ]

        scrcpyProcess?.standardOutput = FileHandle.nullDevice
        scrcpyProcess?.standardError = FileHandle.nullDevice

        do {
            try scrcpyProcess?.run()
            log("scrcpy started")

            // Hide the log view and status when scrcpy is running
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.statusLabel.isHidden = true
                self.logView.enclosingScrollView?.isHidden = true
                // Make background mostly transparent so scrcpy shows through
                self.window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            }
        } catch {
            log("Failed to start scrcpy: \(error.localizedDescription)")
            statusLabel.stringValue = "scrcpy error - is it installed?"
        }
    }

    func stopScrcpy() {
        if let process = scrcpyProcess, process.isRunning {
            process.terminate()
            scrcpyProcess = nil
        }

        // Restore background
        window.contentView?.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        statusLabel.isHidden = false
        logView.enclosingScrollView?.isHidden = false
    }

    @objc func windowDidMove(_ notification: Notification) {
        // Reposition scrcpy window to follow our window
        guard scrcpyProcess?.isRunning == true else { return }
        repositionScrcpy()
    }

    func repositionScrcpy() {
        let windowFrame = window.frame
        let borderWidth: CGFloat = 6

        // Calculate new scrcpy position
        let scrcpyX = Int(windowFrame.origin.x + borderWidth)
        let scrcpyY = Int(NSScreen.main!.frame.height - windowFrame.origin.y - windowFrame.height + borderWidth + toolbarHeight)

        // Use AppleScript to move the scrcpy window
        let script = """
        tell application "System Events"
            tell process "scrcpy"
                if exists window 1 then
                    set position of window 1 to {\(scrcpyX), \(scrcpyY)}
                end if
            end tell
        end tell
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"

        // Write to file
        let logPath = "/Users/asnaroo/Desktop/experiments/miso/miso/platforms/android/development/screen-capture/imp/app.log"
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }

        // Update UI
        DispatchQueue.main.async {
            self.logView.string += logMessage
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    @objc func toggleWindowSize() {
        isSmallMode.toggle()

        let targetSize = isSmallMode ? smallSize : fullSize
        let currentFrame = window.frame

        // Calculate new frame (keeping top-left corner position)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + currentFrame.height - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )

        // Stop scrcpy before resize
        let wasRunning = scrcpyProcess?.isRunning ?? false
        if wasRunning {
            stopScrcpy()
        }

        // Snap to new size (no animation)
        window.setFrame(newFrame, display: true, animate: false)

        // Adjust corner radius proportionally
        let cornerRadius: CGFloat = isSmallMode ? 15 : 30
        window.contentView?.layer?.cornerRadius = cornerRadius

        // Update console button position for new size (in toolbar area)
        let buttonSize: CGFloat = 36
        let scaledToolbarHeight = isSmallMode ? toolbarHeight / 2 : toolbarHeight
        let buttonX: CGFloat = targetSize.width - buttonSize - 12
        let buttonY: CGFloat = targetSize.height - scaledToolbarHeight + (scaledToolbarHeight - buttonSize) / 2
        consoleButton.frame = NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize)

        log(isSmallMode ? "Switched to small mode" : "Switched to full size")

        // Restart scrcpy with new size after a brief delay
        if wasRunning && hasDevice {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startScrcpy()
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
