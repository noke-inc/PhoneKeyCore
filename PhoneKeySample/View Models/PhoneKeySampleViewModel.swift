//
//  PhoneKeySampleViewModel.swift
//  PhoneKeySample
//
//  Created by Joffrey Mann on 1/7/26.
//


import SwiftUI

@MainActor
@Observable
final class PhoneKeySampleViewModel {
    var keyId: String = ""
    var publicKeyBase64: String = ""
    var status: String = ""
    var logs: [String] = []

    var overlockOverride: Bool = false
    var signedCommandJSON: String = ""

    private let keyMgr = PhoneKeyManager(serviceName: "com.noke.phonekey.sample")

    // MARK: - Ensure / Load Phone Key
    func ensurePhoneKey() {
        append("Ensuring phone key …")
        do {
            let info = try keyMgr.ensureKeys()
            keyId = info.keyId
            publicKeyBase64 = info.publicKeyRaw.base64EncodedString()
            status = "Ready"
            append("Key ready: keyId=\(info.keyId)")
            append("PublicKey(32B) base64=\(publicKeyBase64.prefix(28))…")
        } catch {
            status = "Error"
            append("Ensure key failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Build & Sign Minimal Unlock Command
    func buildAndSignUnlockCommand() {
        append("Building unlock command …")

        // Inputs
        let cmdId = UUID().uuidString
        let nonce = Data((0..<16).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
        let now = Date()
        let payload = [
            "channel": "ble",
            "overlock_override": overlockOverride ? "true" : "false"
        ]

        // 1) Build base PhoneKeySignedCommand (createdAt as ISO-8601 string)
        let base = PhoneKeySignedCommand(
            commandId: cmdId,
            type: "unlock",
            createdAt: now.toISO8601String(),         // use your Date extension
            nonce: nonce,
            payload: payload,
            signature: .init(algorithm: "", value: "") // placeholder; signCommand will fill it
        )

        do {
            // 2) Canonicalize + sign using your helper
            let signed = try signCommand(with: keyMgr, base: base)

            // 3) Encode JSON for preview/copy
            let json = try JSONEncoder().encode(signed)
            signedCommandJSON = String(data: json, encoding: .utf8) ?? ""
            append("Command signed. Length=\(json.count) bytes")

        } catch {
            append("Sign failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Utility
    func copyPublicKey() {
        UIPasteboard.general.string = publicKeyBase64
        append("Copied public key base64 to clipboard.")
    }

    func copySignedCommand() {
        UIPasteboard.general.string = signedCommandJSON
        append("Copied signed command to clipboard.")
    }

    func registerPublicKeyWithBackend() {
        // Stub demo: your real app will POST keyId + publicKeyBase64 to backend over TLS.
        append("Stub: registering keyId + publicKey with backend …")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.append("Stub: backend acknowledged registration.")
        }
    }
    
    
    
    func validateCurrentKey() -> Bool {
        do {
            // If ensureKeys() was called earlier, you already have info.seed in memory
            let info = try keyMgr.ensureKeys() // ensures and returns current key
            let validated = try keyMgr.loadExistingKey(info.seed)
            if validated != nil {
                status = "Ready"
                append("Key validated: keyId=\(info.keyId)")
                keyId = info.keyId
                publicKeyBase64 = info.publicKeyRaw.base64EncodedString()
                return true
            } else {
                status = "No Key"
                append("No key found.")
                return false
            }
        } catch {
            status = "Error"
            append("Validation failed: \(error.localizedDescription)")
            return false
        }
    }

    private func append(_ line: String) {
        logs.append("• \(line)")
        if logs.count > 200 { logs.removeFirst(logs.count - 200) }
    }
}


extension Date {
    /// Converts a Date to an ISO-8601 string with fractional seconds (e.g., 2026-01-07T17:45:00.123Z)
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
    
    /// Converts a Date to a string using a custom format (e.g., "yyyy-MM-dd HH:mm:ss")
    func toString(format: String = "yyyy-MM-dd HH:mm:ss", timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        return formatter.string(from: self)
    }
}
