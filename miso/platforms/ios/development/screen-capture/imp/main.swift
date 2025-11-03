import Cocoa
import AVFoundation
import CoreMediaIO

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
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var consoleButton: NSButton!
    var consoleWindow: NSWindow?
    var consoleTextView: NSTextView!
    var logFileHandle: FileHandle?
    var logFileOffset: UInt64 = 0
    var logUpdateTimer: Timer?
    var isSmallMode = false
    let fullSize = NSSize(width: 390, height: 844)
    let smallSize = NSSize(width: 195, height: 422)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar
        setupMenuBar()

        // Enable iOS screen capture devices
        enableiOSScreenCapture()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 844),
            styleMask: [.borderless, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating

        // Replace content view with clickable view
        let clickableView = ClickableView(frame: window.contentView!.bounds)
        clickableView.clickHandler = { [weak self] in
            self?.toggleWindowSize()
        }
        window.contentView = clickableView

        // Add rounded corners and border
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 45
        window.contentView?.layer?.masksToBounds = true
        window.contentView?.layer?.borderWidth = 8
        window.contentView?.layer?.borderColor = NSColor.black.cgColor

        // Create status label at the top
        statusLabel = NSTextField(frame: NSRect(x: 0, y: 800, width: 390, height: 44))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.alignment = .center
        statusLabel.stringValue = "Checking..."
        window.contentView?.addSubview(statusLabel)

        // Create log view
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 10, width: 370, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        logView = NSTextView(frame: scrollView.bounds)
        logView.isEditable = false
        logView.font = NSFont.systemFont(ofSize: 10)
        scrollView.documentView = logView
        window.contentView?.addSubview(scrollView)

        // Create console button on the right edge
        setupConsoleButton()

        window.makeKeyAndOrderFront(nil)

        log("App started")

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

        appMenu.addItem(NSMenuItem(title: "About iPhone Screen Cap", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit iPhone Screen Cap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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
        alert.messageText = "iPhone Screen Cap"
        alert.informativeText = "Version 1.0\n\nCaptures and displays your iPhone screen when connected via USB."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func setupConsoleButton() {
        // Create a small rounded square button at top right corner
        let buttonSize: CGFloat = 30
        let buttonX: CGFloat = fullSize.width - buttonSize - 10  // 10px padding from edge
        let buttonY: CGFloat = fullSize.height - buttonSize - 10  // 10px padding from top
        consoleButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize))
        consoleButton.title = ""
        consoleButton.bezelStyle = .rounded
        consoleButton.setButtonType(.pushOnPushOff)
        consoleButton.target = self
        consoleButton.action = #selector(toggleConsole)

        // Style as a small rounded square
        consoleButton.wantsLayer = true
        consoleButton.layer?.backgroundColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8).cgColor
        consoleButton.layer?.cornerRadius = 8
        consoleButton.layer?.borderWidth = 1
        consoleButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor

        // Add chevron label centered in button
        let label = NSTextField(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        label.stringValue = ">"
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .black
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
            logUpdateTimer?.invalidate()
            logUpdateTimer = nil
        } else {
            // Position console to the right of the main window
            let mainFrame = window.frame
            let consoleFrame = NSRect(
                x: mainFrame.maxX + 10,
                y: mainFrame.minY,
                width: 400,
                height: mainFrame.height
            )
            consoleWindow?.setFrame(consoleFrame, display: true)
            consoleWindow?.makeKeyAndOrderFront(nil)

            // Start updating logs
            startLogUpdates()
        }
    }

    func setupConsoleWindow() {
        consoleWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 844),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        consoleWindow?.title = "Console"
        consoleWindow?.isReleasedWhenClosed = false
        consoleWindow?.level = .floating

        // Create text view for console
        let scrollView = NSScrollView(frame: consoleWindow!.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        consoleTextView = NSTextView(frame: scrollView.bounds)
        consoleTextView.isEditable = false
        consoleTextView.font = NSFont(name: "Menlo", size: 11)
        consoleTextView.textColor = .green
        consoleTextView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        consoleTextView.autoresizingMask = [.width, .height]

        scrollView.documentView = consoleTextView
        consoleWindow?.contentView?.addSubview(scrollView)
    }

    func startLogUpdates() {
        // Check if watch-logs.py is running, start it if not
        ensureWatchLogsRunning()

        // Find the device-logs.txt file
        let logPath = "/Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/ios/device-logs.txt"

        // Wait a moment for watch-logs to create the file if it just started
        Thread.sleep(forTimeInterval: 1.0)

        // Try to open file
        if let fileHandle = FileHandle(forReadingAtPath: logPath) {
            logFileHandle = fileHandle

            // Seek to end first time
            if logFileOffset == 0 {
                logFileOffset = fileHandle.seekToEndOfFile()
            } else {
                try? fileHandle.seek(toOffset: logFileOffset)
            }

            // Update immediately
            updateConsoleLog()

            // Start timer to update every 0.5 seconds
            logUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.updateConsoleLog()
            }
        } else {
            consoleTextView.string = "Could not open log file:\n\(logPath)\n\nTrying to start watch-logs.py..."
        }
    }

    func ensureWatchLogsRunning() {
        // Check if watch-logs.py is already running
        let checkTask = Process()
        checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkTask.arguments = ["-f", "watch-logs.py"]

        let pipe = Pipe()
        checkTask.standardOutput = pipe

        do {
            try checkTask.run()
            checkTask.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                // watch-logs.py is already running
                return
            }
        } catch {
            // Error checking, assume not running
        }

        // Not running, start it
        let watchLogsDir = "/Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/ios"
        let startTask = Process()
        startTask.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        startTask.arguments = ["\(watchLogsDir)/watch-logs.py"]
        startTask.currentDirectoryURL = URL(fileURLWithPath: watchLogsDir)

        // Redirect output to /dev/null so it runs in background
        startTask.standardOutput = FileHandle.nullDevice
        startTask.standardError = FileHandle.nullDevice

        do {
            try startTask.run()
            consoleTextView.string = "Started watch-logs.py...\n\n"
        } catch {
            consoleTextView.string = "Failed to start watch-logs.py: \(error.localizedDescription)\n"
        }
    }

    func updateConsoleLog() {
        guard let fileHandle = logFileHandle else { return }

        // Read new data
        let data = fileHandle.availableData

        if data.count > 0 {
            if let newText = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.consoleTextView.string += newText
                    self.consoleTextView.scrollToEndOfDocument(nil)
                }
            }

            // Update offset
            logFileOffset = fileHandle.offsetInFile
        }
    }

    func checkForDevice() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPUSBDataType"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            if let output = String(data: data, encoding: .utf8) {
                if output.contains("iPhone") {
                    // Try to extract device name
                    let lines = output.components(separatedBy: .newlines)
                    for (_, line) in lines.enumerated() {
                        if line.contains("iPhone") && !line.contains("iPhone:") {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            if trimmed.hasSuffix(":") {
                                let name = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                                statusLabel.stringValue = name

                                // Detect transition from no device to device
                                if !hasDevice {
                                    startCapture()
                                }
                                return
                            }
                        }
                    }
                    statusLabel.stringValue = "iPhone Connected"

                    // Detect transition from no device to device
                    if !hasDevice {
                        startCapture()
                    }
                } else {
                    hasDevice = false
                    statusLabel.stringValue = "No device found"
                }
            } else {
                hasDevice = false
                statusLabel.stringValue = "No device found"
            }
        } catch {
            statusLabel.stringValue = "Error: \(error.localizedDescription)"
        }
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"

        // Write to file
        let logPath = "/Users/asnaroo/Desktop/experiments/iphonecap/app.log"
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

    func enableiOSScreenCapture() {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var allow: UInt32 = 1
        let sizeOfAllow = UInt32(MemoryLayout<UInt32>.size)
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, sizeOfAllow, &allow)
        log("Enabled iOS screen capture devices")
    }

    func startCapture() {
        log("Starting capture...")

        // Try all available device types (macOS compatible only)
        let allDeviceTypes: [AVCaptureDevice.DeviceType] = [
            .external,
            .builtInWideAngleCamera,
            .deskViewCamera
        ]

        var allDevices: [AVCaptureDevice] = []
        for deviceType in allDeviceTypes {
            let session = AVCaptureDevice.DiscoverySession(
                deviceTypes: [deviceType],
                mediaType: .video,
                position: .unspecified
            )
            allDevices.append(contentsOf: session.devices)
        }

        log("Video devices: \(allDevices.count)")
        for device in allDevices {
            log("  - \(device.localizedName) (type: \(device.deviceType.rawValue))")
        }

        // Check muxed media type (this is where iOS devices appear!)
        let muxedSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .muxed,
            position: .unspecified
        )
        log("Muxed devices: \(muxedSession.devices.count)")
        for device in muxedSession.devices {
            log("  - \(device.localizedName) (type: \(device.deviceType.rawValue))")
            allDevices.append(device)
        }

        // Also try AVCaptureDevice.default for muxed
        if let defaultMuxed = AVCaptureDevice.default(for: .muxed) {
            log("Default muxed device: \(defaultMuxed.localizedName)")
            if !allDevices.contains(where: { $0.uniqueID == defaultMuxed.uniqueID }) {
                allDevices.append(defaultMuxed)
            }
        }

        guard let iPhoneDevice = allDevices.first(where: { device in
            device.localizedName.lowercased().contains("phone")
        }) else {
            log("Could not find iPhone capture device yet, will retry...")
            statusLabel.stringValue = "Waiting for iPhone..."
            // Keep hasDevice true so we don't spam the logs, but device will be retried on next timer tick
            return
        }

        log("Found iPhone device: \(iPhoneDevice.localizedName)")

        do {
            let input = try AVCaptureDeviceInput(device: iPhoneDevice)
            log("Created capture input")

            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .low  // Quarter resolution
            log("Created capture session with preset: low")

            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
                log("Added input to session")
            } else {
                log("ERROR: Cannot add input to session")
            }

            // Create preview layer with inset for border
            let borderWidth: CGFloat = 8
            let bounds = window.contentView!.bounds
            let insetFrame = NSRect(
                x: borderWidth,
                y: borderWidth,
                width: bounds.width - (borderWidth * 2),
                height: bounds.height - (borderWidth * 2)
            )

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.frame = insetFrame
            previewLayer?.videoGravity = .resizeAspectFill
            window.contentView?.layer = CALayer()
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 45
            window.contentView?.layer?.masksToBounds = true
            window.contentView?.layer?.borderWidth = borderWidth
            window.contentView?.layer?.borderColor = NSColor.black.cgColor
            window.contentView?.layer?.addSublayer(previewLayer!)
            log("Created preview layer")

            // Re-add status label and console button on top
            window.contentView?.addSubview(statusLabel)
            window.contentView?.addSubview(consoleButton)

            // Start capture
            log("Starting capture session...")
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
                DispatchQueue.main.async {
                    self.log("Capture session started: \(self.captureSession?.isRunning ?? false)")

                    // Hide UI elements when capture starts successfully (but keep console button visible)
                    if self.captureSession?.isRunning == true {
                        self.hasDevice = true  // Only set to true when capture actually starts
                        self.statusLabel.isHidden = true
                        self.logView.enclosingScrollView?.isHidden = true
                        self.consoleButton.isHidden = false  // Ensure button stays visible
                    }
                }
            }

            // Observe interruptions and errors
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(captureSessionWasInterrupted),
                name: AVCaptureSession.wasInterruptedNotification,
                object: captureSession
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(captureSessionInterruptionEnded),
                name: AVCaptureSession.interruptionEndedNotification,
                object: captureSession
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(captureSessionRuntimeError),
                name: AVCaptureSession.runtimeErrorNotification,
                object: captureSession
            )

        } catch {
            log("ERROR starting capture: \(error.localizedDescription)")
            statusLabel.stringValue = "Error starting capture: \(error.localizedDescription)"
        }
    }

    @objc func captureSessionWasInterrupted(_ notification: Notification) {
        log("Capture session interrupted")
        cleanupCapture()
    }

    @objc func captureSessionInterruptionEnded(_ notification: Notification) {
        log("Capture session interruption ended")
    }

    @objc func captureSessionRuntimeError(_ notification: Notification) {
        log("Capture session runtime error")
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            log("Error: \(error.localizedDescription)")
        }
        cleanupCapture()
    }

    func cleanupCapture() {
        log("Cleaning up capture session")

        captureSession?.stopRunning()
        captureSession = nil

        previewLayer?.removeFromSuperlayer()
        previewLayer = nil

        hasDevice = false

        // Show UI elements again
        statusLabel.isHidden = false
        logView.enclosingScrollView?.isHidden = false
        statusLabel.stringValue = "No device found"
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

        // Snap to new size (no animation)
        window.setFrame(newFrame, display: true, animate: false)

        // Adjust corner radius proportionally
        let cornerRadius: CGFloat = isSmallMode ? 22.5 : 45
        window.contentView?.layer?.cornerRadius = cornerRadius

        // Update preview layer frame if it exists, with inset for border
        if let previewLayer = previewLayer {
            let borderWidth: CGFloat = 8
            let bounds = window.contentView!.bounds
            let insetFrame = NSRect(
                x: borderWidth,
                y: borderWidth,
                width: bounds.width - (borderWidth * 2),
                height: bounds.height - (borderWidth * 2)
            )
            previewLayer.frame = insetFrame
        }

        // Update console button position for new size
        let buttonSize: CGFloat = 30
        let buttonX: CGFloat = targetSize.width - buttonSize - 10  // 10px padding from edge
        let buttonY: CGFloat = targetSize.height - buttonSize - 10  // 10px padding from top
        consoleButton.frame = NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize)

        log(isSmallMode ? "Switched to small mode" : "Switched to full size")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
