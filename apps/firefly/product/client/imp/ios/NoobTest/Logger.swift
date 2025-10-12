import Foundation
import OSLog

class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.miso.logger", qos: .utility)
    private let osLogger = os.Logger(subsystem: "com.miso.noobtest", category: "logger")

    private init() {
        // OSLog for debugging
        osLogger.info("hello from OSLog")

        // Create log file in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documentsPath.appendingPathComponent("app.log")

        print("[Logger] Log file path: \(logFileURL.path)")
        osLogger.info("Log file path: \(self.logFileURL.path, privacy: .public)")

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            let created = FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            print("[Logger] File created: \(created)")
        } else {
            print("[Logger] File already exists")
        }

        // Open file handle for appending
        do {
            fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle?.seekToEndOfFile()
            print("[Logger] File handle opened successfully")
        } catch {
            fileHandle = nil
            print("[Logger] Failed to open file handle: \(error)")
        }

        // Log initialization
        let initMessage = "\n=== Logger initialized at \(Date()) ===\n"
        writeToFile(initMessage)
    }

    deinit {
        try? fileHandle?.close()
    }

    // Main logging function
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let formattedMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        writeToFile(formattedMessage)
    }

    // Convenience methods
    func debug(_ message: String) {
        osLogger.debug("[APP] \(message)")
        log(message, level: .debug)
    }

    func info(_ message: String) {
        osLogger.info("[APP] \(message)")
        log(message, level: .info)
    }

    func warning(_ message: String) {
        osLogger.warning("[APP] \(message)")
        log(message, level: .warning)
    }

    func error(_ message: String) {
        osLogger.error("[APP] \(message)")
        log(message, level: .error)
    }

    // Write to file asynchronously
    private func writeToFile(_ message: String) {
        print("[Logger] Writing: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        queue.async { [weak self] in
            guard let data = message.data(using: .utf8) else {
                print("[Logger] Failed to convert message to data")
                return
            }
            guard let fileHandle = self?.fileHandle else {
                print("[Logger] No file handle available")
                return
            }
            fileHandle.write(data)
            try? fileHandle.synchronize()  // Ensure data is written to disk
            print("[Logger] Write completed")
        }
    }

    // Get log file contents
    func getLogContents() -> String? {
        try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    // Clear log file
    func clearLog() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileHandle?.truncate(atOffset: 0)
            let clearMessage = "\n=== Log cleared at \(Date()) ===\n"
            self.writeToFile(clearMessage)
        }
    }

    // Date formatter for timestamps
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// Log levels
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
