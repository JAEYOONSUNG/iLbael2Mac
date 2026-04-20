import Foundation

enum WiFiAutomationError: LocalizedError {
    case missingPrinterSSID
    case missingWiFiDevice
    case commandFailed(String)
    case connectionTimeout(String)

    var errorDescription: String? {
        switch self {
        case .missingPrinterSSID:
            return "Printer Wi-Fi SSID is empty."
        case .missingWiFiDevice:
            return "Could not find the Mac's Wi-Fi device."
        case let .commandFailed(message):
            return message
        case let .connectionTimeout(message):
            return message
        }
    }
}

struct WiFiPrintSession {
    let service: String
    let previousSSID: String?
    let settings: PrintAutomationSettings

    func restore() async throws {
        guard settings.enabled, settings.reconnectToPreviousWiFi else { return }
        guard let previousSSID, !previousSSID.isEmpty, previousSSID != settings.printerSSID else { return }
        try await WiFiPrintAutomation.connectAndWait(
            service: service,
            ssid: previousSSID,
            password: nil
        )
    }
}

enum WiFiPrintAutomation {
    static let airportTool = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

    static func wifiDevice() -> String? {
        guard let output = try? run("/usr/sbin/networksetup", ["-listallhardwareports"]) else {
            return nil
        }

        let lines = output.components(separatedBy: .newlines)
        var sawWiFiPort = false

        for line in lines {
            if line.hasPrefix("Hardware Port: ") {
                sawWiFiPort = line == "Hardware Port: Wi-Fi"
                continue
            }

            if sawWiFiPort, line.hasPrefix("Device: ") {
                return line.replacingOccurrences(of: "Device: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    static func currentSSID(service: String) -> String? {
        guard FileManager.default.fileExists(atPath: airportTool) else {
            return nil
        }
        guard let output = try? run(airportTool, ["-I"]) else {
            return nil
        }
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("SSID: ") {
                return trimmed.replacingOccurrences(of: "SSID: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    static func preferredNetworks() -> [String] {
        guard let device = wifiDevice(),
              let output = try? run("/usr/sbin/networksetup", ["-listpreferredwirelessnetworks", device]) else {
            return []
        }

        return output
            .components(separatedBy: .newlines)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func autoDetectedPrinterSSID() -> String? {
        let candidates = preferredNetworks()
        let ranked = candidates.sorted { lhs, rhs in
            scoreCandidate(lhs) > scoreCandidate(rhs)
        }
        return ranked.first(where: { scoreCandidate($0) > 0 })
    }

    private static func scoreCandidate(_ ssid: String) -> Int {
        let lower = ssid.lowercased()
        var score = 0
        if lower.hasPrefix("direct-") { score += 100 }
        if lower.contains("laserjet") { score += 40 }
        if lower.contains("hp") { score += 20 }
        if lower.contains("print") { score += 10 }
        return score
    }

    static func prepare(settings: PrintAutomationSettings) async throws -> WiFiPrintSession? {
        guard settings.enabled else { return nil }
        let printerSSID = settings.printerSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !printerSSID.isEmpty else {
            throw WiFiAutomationError.missingPrinterSSID
        }

        let previousSSID = currentSSID(service: settings.wifiService)
        if previousSSID != printerSSID {
            try await connectAndWait(
                service: settings.wifiService,
                ssid: printerSSID,
                password: settings.printerPassword.isEmpty ? nil : settings.printerPassword
            )
        }

        return WiFiPrintSession(
            service: settings.wifiService,
            previousSSID: previousSSID,
            settings: settings
        )
    }

    static func connect(service: String, ssid: String, password: String?) throws {
        var arguments = ["-setairportnetwork", service, ssid]
        if let password, !password.isEmpty {
            arguments.append(password)
        }
        _ = try run("/usr/sbin/networksetup", arguments)
    }

    static func connectAndWait(
        service: String,
        ssid: String,
        password: String?,
        timeoutSeconds: Double = 12.0
    ) async throws {
        try connect(service: service, ssid: ssid, password: password)
        try await waitUntilConnected(service: service, expectedSSID: ssid, timeoutSeconds: timeoutSeconds)
    }

    static func waitUntilConnected(
        service: String,
        expectedSSID: String,
        timeoutSeconds: Double = 12.0
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if currentSSID(service: service) == expectedSSID {
                return
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        throw WiFiAutomationError.connectionTimeout("Timed out waiting to connect to \(expectedSSID)")
    }

    @discardableResult
    private static func run(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = error.isEmpty ? output : error
            throw WiFiAutomationError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
