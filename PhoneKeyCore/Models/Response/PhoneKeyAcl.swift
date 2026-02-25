//
//  PhoneKeyAcl.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

// MARK: - ISO8601 helpers (kept for general use with utilities/mocks)

/// A resilient ISO‑8601 parser that supports Zulu UTC, offsets, and fractional seconds.
public enum ISO8601 {
    /// Primary: supports fractional seconds and time zone offsets.
    public static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for absolute instants
        return f
    }()
    
    /// Fallback: no fractional seconds.
    public static let basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    /// Parse function used by decoders (tries fractional → basic).
    public static func parse(_ s: String) -> Date? {
        if let d = withFractional.date(from: s) { return d }
        return basic.date(from: s)
    }
    
    /// Encoder counterpart that always emits RFC 3339/ISO‑8601 with fractional seconds.
    public static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}

// MARK: - Envelope

/// Top‑level wrapper the server returns.
/// Example payload:
/// {
///   "result": "success",
///   "acl": { ... },
///   "aclSignature": "MEQCIG..."
/// }
public struct PhoneKeyAclEnvelope: Codable {
    public let result: String
    public var acl: PhoneKeyAcl
    public var aclSignature: String
    public var aclBinary: String

    enum CodingKeys: String, CodingKey {
        case result
        case acl
        case aclSignature
        case aclBinary
    }

    public init(result: String, acl: PhoneKeyAcl, aclSignature: String, aclBinary: String) {
        self.result = result
        self.acl = acl
        self.aclSignature = aclSignature
        self.aclBinary = aclBinary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = try container.decode(String.self, forKey: .result)
        self.acl = try container.decode(PhoneKeyAcl.self, forKey: .acl)
        self.aclSignature = try container.decode(String.self, forKey: .aclSignature)
        self.aclBinary = try container.decode(String.self, forKey: .aclBinary)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(result, forKey: .result)
        try container.encode(acl, forKey: .acl)
        // Prefer explicit aclSignature; otherwise derive from acl.signature.value if present
        let sigValue = aclSignature.isEmpty ? (aclSignature) : aclSignature
        try container.encode(sigValue, forKey: .aclSignature)
        try container.encode(aclBinary, forKey: .aclBinary)
    }
}

// MARK: - ACL

public struct PhoneKeyAcl: Codable {
    // MARK: Nested Types

    public struct Permissions: Codable {
        public let unlock: Bool
        public let overrideOverlock: Bool

        enum CodingKeys: String, CodingKey {
            case unlock
            case overrideOverlock
        }

        /// Accept either:
        /// - array-of-strings: ["unlock","overrideOverlock"]
        /// - keyed booleans: { "unlock": true, ... }
        public init(from decoder: Decoder) throws {
            // Try array-of-strings first (server sample form)
            if let single = try? decoder.singleValueContainer(),
               let list = try? single.decode([String].self) {
                func on(_ keys: String...) -> Bool {
                    keys.contains { key in list.contains(key) }
                }
                self.unlock = on("unlock")
                self.overrideOverlock = on("overrideOverlock")
                return
            }

            // Fallback to keyed booleans
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.unlock = (try? c.decode(Bool.self, forKey: .unlock)) ?? false
            self.overrideOverlock = (try? c.decode(Bool.self, forKey: .overrideOverlock)) ?? false
        }

        public init(unlock: Bool, overrideOverlock: Bool) {
            self.unlock = unlock
            self.overrideOverlock = overrideOverlock
        }

        /// Encode back as array-of-strings to match server’s payload shape.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            var list: [String] = []
            if unlock { list.append("unlock") }
            if overrideOverlock { list.append("overrideOverlock") }
            try container.encode(list)
        }
    }

    public struct Signature: Codable {
        public let algorithm: String   // e.g., "Ed25519", "ECDSA_P256"
        public let value: String       // Base64-encoded signature

        enum CodingKeys: String, CodingKey {
            case algorithm
            case value
        }

        public init(algorithm: String = "ECDSA_P256", value: String) {
            self.algorithm = algorithm
            self.value = value
        }
    }
    
    public struct Schedule: Codable, Equatable {
        let start: Date
        let end: Date

        private enum CodingKeys: String, CodingKey {
            case start
            case end
        }

        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }

        public init(from decoder: Decoder) throws {
            // We’ll decode values flexibly (Int/Double/String) then normalize via a local helper
            let c = try decoder.container(keyedBy: CodingKeys.self)

            // Try canonical keys first
            if let s = try? Self.decodeFlexibleDateValue(container: c, key: .start),
               let e = try? Self.decodeFlexibleDateValue(container: c, key: .end) {
                self.init(start: s, end: e)
                return
            }

            // Try alternate keys (start/end)
            if let s = try? Self.decodeFlexibleDateValue(container: c, key: .start),
               let e = try? Self.decodeFlexibleDateValue(container: c, key: .end) {
                self.init(start: s, end: e)
                return
            }

            throw DecodingError.dataCorrupted(.init(
                codingPath: c.codingPath,
                debugDescription: "Could not decode Schedule (start/end)."
            ))
        }

        // This mirrors your decodeFlexibleDate but scoped locally for embedded objects.
        // If you prefer, you can make this call your parent type’s method.
        private static func decodeFlexibleDateValue(
            container c: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) throws -> Date {
            if let secs = try? c.decode(Int.self, forKey: key) {
                return Date(timeIntervalSince1970: TimeInterval(secs))
            }
            if let secsD = try? c.decode(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: secsD)
            }
            if let str = try? c.decode(String.self, forKey: key) {
                if let secs = Int(str) {
                    return Date(timeIntervalSince1970: TimeInterval(secs))
                }
                if let d = ISO8601.parse(str) {
                    return d
                }
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: c.codingPath + [key],
                debugDescription: "Expected epoch seconds (Int/Double/String) or ISO8601 string for \(key)."
            ))
        }
    }

    // MARK: Properties

    /// NOW OPTIONAL; decodes from Int or String; stores as String?
    public let trackingId: String?
    public let lockMac: String
    public let phonePublicKey: String        // JSON key: "phonePubKey"
    public let issuedAt: Date                // Epoch seconds in payload
    public let expiresAt: Date               // Epoch seconds in payload
    /// NOW OPTIONAL
    public let schedule: [Schedule]?
    public let permissions: Permissions

    enum CodingKeys: String, CodingKey {
        case trackingId
        case lockMac
        case phonePublicKey = "phonePubKey"
        case issuedAt
        case expiresAt
        case schedule
        case permissions
    }

    // MARK: Decoding

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // trackingId: accept Int or String; allow missing -> nil
        if let idInt = try? c.decode(Int.self, forKey: .trackingId) {
            self.trackingId = String(idInt)
        } else if let idString = try? c.decode(String.self, forKey: .trackingId) {
            self.trackingId = idString
        } else {
            self.trackingId = nil
        }

        self.lockMac = try c.decode(String.self, forKey: .lockMac)
        self.phonePublicKey = try c.decode(String.self, forKey: .phonePublicKey)

        // Dates (epoch seconds). Also accept Double or String (numeric/ISO8601) for resilience.
        self.issuedAt = try Self.decodeFlexibleDate(container: c, key: .issuedAt)
        self.expiresAt = try Self.decodeFlexibleDate(container: c, key: .expiresAt)

        // schedule is optional
        self.schedule = try? c.decode(Array<Schedule>.self, forKey: .schedule)
        self.permissions = try c.decode(Permissions.self, forKey: .permissions)
        //self.signature = try c.decodeIfPresent(Signature.self, forKey: .signature) // Usually nil; set by envelope
    }

    // MARK: Encoding

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        // trackingId: encode when non-nil; Int if numeric string, else String
        if let trackingId {
            if let idInt = Int(trackingId) {
                try c.encode(idInt, forKey: .trackingId)
            } else {
                try c.encode(trackingId, forKey: .trackingId)
            }
        }

        try c.encode(lockMac, forKey: .lockMac)
        try c.encode(phonePublicKey, forKey: .phonePublicKey)

        // Encode dates as epoch seconds (Int), to match payload
        try c.encode(Int(issuedAt.timeIntervalSince1970), forKey: .issuedAt)
        try c.encode(Int(expiresAt.timeIntervalSince1970), forKey: .expiresAt)

        // schedule: omit when nil
        if let schedule { try c.encode(schedule, forKey: .schedule) }

        try c.encode(permissions, forKey: .permissions)
        //try c.encodeIfPresent(signature, forKey: .signature) // Not used by server in sample; envelope handles top-level
    }

    // MARK: Inits

    public init(
        trackingId: String?,
        lockMac: String,
        phonePublicKey: String,
        issuedAt: Date,
        expiresAt: Date,
        schedule: [Schedule]?,
        permissions: PhoneKeyAcl.Permissions,
    ) {
        self.trackingId = trackingId
        self.lockMac = lockMac
        self.phonePublicKey = phonePublicKey
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.schedule = schedule
        self.permissions = permissions
    }

    // MARK: - Helpers

    private static func decodeFlexibleDate(container c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Date {
        if let secs = try? c.decode(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(secs))
        }
        if let secsD = try? c.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: secsD)
        }
        if let str = try? c.decode(String.self, forKey: key) {
            if let secs = Int(str) {
                return Date(timeIntervalSince1970: TimeInterval(secs))
            }
            if let d = ISO8601.parse(str) {
                return d
            }
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: c.codingPath + [key],
            debugDescription: "Expected epoch seconds (Int/Double/String) or ISO8601 string for \(key)."
        ))
    }
}

// MARK: - JSON Encoder/Decoder (ISO 8601 with fractional seconds) – utility

public enum JSONISO8601 {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        // RFC3339/ISO8601 + fractional seconds
        if #available(iOS 11.0, *) {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            f.timeZone = TimeZone(secondsFromGMT: 0)
            e.dateEncodingStrategy = .custom { date, enc in
                var container = enc.singleValueContainer()
                try container.encode(f.string(from: date))
            }
        } else {
            e.dateEncodingStrategy = .iso8601
        }
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        if #available(iOS 11.0, *) {
            d.dateDecodingStrategy = .custom { dec in
                let s = try dec.singleValueContainer().decode(String.self)
                if let dt = ISO8601.parse(s) {
                    return dt
                }
                throw DecodingError.dataCorrupted(.init(
                    codingPath: dec.codingPath,
                    debugDescription: "Invalid ISO8601 date string: \(s)"
                ))
            }
        } else {
            d.dateDecodingStrategy = .iso8601
        }
        return d
    }
}

// MARK: - PhoneKeyAcl mocks & conveniences

public extension PhoneKeyAcl {

    /// A simple deterministic byte array (0x00, 0x01, 0x02, …) of given length.
    private static func sequentialBytes(_ count: Int, start: UInt8 = 0) -> Data {
        Data((0..<count).map { UInt8((Int(start) + $0) & 0xFF) })
    }

    /// Permissions with convenient defaults (all enabled)
    private static func defaultPermissions() -> PhoneKeyAcl.Permissions {
        .init(unlock: true, overrideOverlock: true)
    }

    /// Create a mock ACL with **Ed25519** metadata (32‑byte public key, 64‑byte signature).
    /// - Parameters:
    ///   - now: Base time for issuedAt/expiresAt.
    ///   - lockMac: Bluetooth MAC-like string (cosmetic).
    ///   - phoneKeyId: Arbitrary key id.
    ///   - trackingId: Optional ACL id.
    ///   - includeSignature: Include a dummy signature (Base64 of 64 bytes).
    /// - Returns: PhoneKeyAcl
    static func mockEd25519(
        now: Date = Date(),
        lockMac: String = "AA:BB:CC:DD:EE:FF",
        phoneKeyId: String? = "ed25519-key-0001",
        trackingId: String? = "1",
        includeSignature: Bool = true
    ) -> PhoneKeyAcl {

        let issuedAt = now
        let expiresAt = now.addingTimeInterval(72 * 3600) // +72h
        let schedule: [Schedule]? = [
            Schedule(start: Date(), end: Date().addingTimeInterval(24 * 3600)),
        ]

        // 32-byte Ed25519 public key → Base64
        let pub32 = sequentialBytes(32, start: 0x11).base64EncodedString()

        return PhoneKeyAcl(
            trackingId: trackingId,
            lockMac: lockMac,
            phonePublicKey: pub32,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            schedule: schedule,
            permissions: defaultPermissions(),
        )
    }

    /// Create a mock ACL with **ECDSA P‑256** metadata.
    ///
    /// > NOTE: For P‑256, public keys are typically **65 bytes** (uncompressed X9.63) or **33 bytes** (compressed).
    /// > Your `phonePublicKey` comment mentions **32 bytes** (Ed25519). Adjust `p256PublicKeyLength`
    /// > to match what your server/firmware expects.
    ///
    /// - Parameters:
    ///   - p256PublicKeyLength: 65 (uncompressed) or 33 (compressed) by default.
    ///   - includeSignature: Include a dummy raw `(r||s)` 64‑byte signature in Base64.
    static func mockP256(
        now: Date = Date(),
        lockMac: String = "AA:BB:CC:DD:EE:FF",
        phoneKeyId: String? = "p256-key-0001",
        trackingId: String? = "2",
        p256PublicKeyLength: Int = 65,
        includeSignature: Bool = true
    ) -> PhoneKeyAcl {

        let issuedAt = now
        let expiresAt = now.addingTimeInterval(48 * 3600) // +48h
        let schedule: [Schedule]? = [
            Schedule(start: Date(), end: Date().addingTimeInterval(24 * 3600)),
        ]
        
        // Build a plausible public key buffer.
        // If uncompressed (65), first byte is 0x04; rest are XY coordinates.
        var pub = Data()
        if p256PublicKeyLength == 65 {
            pub.append(0x04)
            pub.append(sequentialBytes(64, start: 0x21))
        } else {
            pub = sequentialBytes(p256PublicKeyLength, start: 0x31)
        }

        return PhoneKeyAcl(
            trackingId: trackingId,
            lockMac: lockMac,
            phonePublicKey: pub.base64EncodedString(),
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            schedule: schedule,
            permissions: defaultPermissions(),
        )
    }

    // MARK: - JSON convenience for mocks

    /// JSON-encoded bytes for a mock Ed25519 ACL (pretty-printed, ISO8601 fractional for general purpose).
    /// Note: When encoding `PhoneKeyAcl` itself, dates are encoded as **epoch seconds** per server shape.
    static func mockEd25519JSON(now: Date = Date()) throws -> Data {
        let acl = mockEd25519(now: now)
        return try JSONEncoder().encode(acl) // ACL encodes epoch seconds; omits optionals when nil
    }

    /// JSON-encoded bytes for a mock P-256 ACL.
    static func mockP256JSON(now: Date = Date(), p256PublicKeyLength: Int = 65) throws -> Data {
        let acl = mockP256(now: now, p256PublicKeyLength: p256PublicKeyLength)
        return try JSONEncoder().encode(acl) // ACL encodes epoch seconds; omits optionals when nil
    }
    
    /// Produce mock ACL raw bytes of any length (replace with real base64-decoded ACL later).
    static func mockAclRawBytes(length: Int, start: UInt8 = 0x00) -> Data {
        sequentialBytes(length, start: start)
    }
    
    /// Build ACL JSON string (exactly as you do today)
    static func makeAclJsonString(
        lockMac: String = "AA:BB:CC:DD:EE:FF",
        phoneKeyId: String? = "p256-key-0001",
        trackingId: String? = "2",
        issuedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(48 * 3600),
        schedule: String? = "697A332A-697AA300,697B75F0-697B84AA"
    ) -> String {
        return "{ \"trackingId\": \(trackingId ?? "null"), " +
        "\"lockMac\": \"\(lockMac)\", " +
        "\"phonePubKey\": \"\(phoneKeyId ?? "null")\", " +
        "\"issuedAt\": \(Int(issuedAt.timeIntervalSince1970)), " +
        "\"expiresAt\": \(Int(expiresAt.timeIntervalSince1970)), " +
        "\"schedule\": \(schedule != nil ? "\"\(schedule!)\"" : "null"), " +
        "\"permissions\": [\"unlock\",\"overrideOverlock\"] }"
    }

    /// Create the BLE payload: Base64(ACL JSON) + Base64(signature)
    /// Returns (aclJsonBytes, payloadBytes)
    static func makeAclPayloadWithSignature(
        keyManager: PhoneKeyManager
    ) throws -> (aclJson: Data, payload: Data, aclLengthForHeader: Int, signature: Data) {
        let jsonString = makeAclJsonString()
        let jsonData = Data(jsonString.utf8)

        // Sign the JSON bytes
        // NOTE: Your PhoneKeyManager must return signature bytes in the format the lock expects (DER or raw r||s). You’re already base64-encoding it, so both work as long as the verifier mirrors it.
        let signatureBytes = try keyManager.sign(jsonData, userId: "")

        let aclB64 = jsonData.base64EncodedString()          // ASCII
        let sigB64 = signatureBytes.base64EncodedString()    // ASCII

        // Per protocol: append signature at the end, back-to-back (NO delimiter)
        let concatenated = aclB64 + sigB64

        // Payload to send over BLE is the UTF-8 bytes of that ASCII string
        let payload = Data(concatenated.utf8)

        // IMPORTANT: the final-chunk 4 hex digits are the ACL length BYTES (not base64 length)
        let aclLengthForHeader = jsonData.count

        return (aclJson: jsonData, payload: payload, aclLengthForHeader: aclLengthForHeader, signature: signatureBytes)
    }

    /// Build fixed 128-byte ACL frames:
    /// - Non-final frames: [seqHeader] + payload + padding
    ///   where seqHeader increments: 0x00, 0x01, 0x02, ...
    ///   (skipping `lastTag` if the sequence would collide)
    /// - Final frame: [lastTag(XX)] + ASCII hex length (4 chars) + payload + padding
    ///
    /// Notes:
    /// - The FINAL chunk **starts with XX** (the `lastTag` byte), immediately followed
    ///   by **4 ASCII hex digits** of the *ACL length you intend to signal*.
    /// - Every frame is padded with 0x00 to exactly `chunkSize` bytes (default 128).
    /// - `acl` should be your payload bytes: Base64(ACL_JSON) + Base64(signature) with no delimiter.
    static func buildAclFrames128(
        acl: Data,
        chunkSize: Int = 128,
        lastTag: UInt8 = 0xFF,            // <-- Your protocol's XX. Choose a value that won't be hit by the sequence.
        lengthForFinalHeader: Int? = nil  // <-- 4 ASCII hex digits in final header (e.g., ACL JSON byte count)
    ) -> [Data] {

        func asciiHexLength(_ len: Int) -> Data {
            Data(String(format: "%04X", len).utf8) // 4 ASCII hex chars, uppercase
        }

        precondition(chunkSize >= 16, "chunkSize too small for headers + payload")

        // Final header = 1 byte lastTag + 4 ASCII hex digits
        let signaledLength = lengthForFinalHeader ?? acl.count
        precondition(signaledLength <= 0xFFFF, "lengthForFinalHeader must fit in 4 hex digits")

        let finalHeader = Data([lastTag]) + asciiHexLength(signaledLength)
        let stdPayloadCap  = chunkSize - 1                // 1-byte header
        let finalPayloadCap = chunkSize - finalHeader.count // 5 bytes header

        var frames: [Data] = []
        var offset = 0
        var seq: UInt8 = 0x00

        // Emit non-final frames until what's left fits into one final frame
        while (acl.count - offset) > finalPayloadCap {
            // Skip lastTag in the sequence (reserve it strictly for the final frame)
            if seq == lastTag {
                seq &+= 1 // move to next value; wrap is fine for very large sequences
            }

            let take = min(stdPayloadCap, acl.count - offset)
            var frame = Data(capacity: chunkSize)
            frame.append(seq)                       // sequential binary header
            frame.append(acl[offset ..< offset + take])

            if frame.count < chunkSize {
                frame.append(Data(count: chunkSize - frame.count))
            }

            frames.append(frame)
            offset += take
            seq &+= 1
        }

        // Emit FINAL frame: [lastTag] + 4 ASCII hex digits + remaining payload + padding
        var lastFrame = Data(capacity: chunkSize)
        lastFrame.append(finalHeader)
        if offset < acl.count {
            lastFrame.append(acl[offset ..< acl.count])
        }
        if lastFrame.count < chunkSize {
            lastFrame.append(Data(count: chunkSize - lastFrame.count))
        }
        frames.append(lastFrame)

        return frames
    }
}

// MARK: - Example usage (for reference)
/*
let sample = """
{
    "result": "success",
    "acl": {
        "trackingId": 1,
        "lockMac": "F7:AB:DB:66:23:22",
        "issuedAt": 1769616170,
        "expiresAt": 1769702570,
        "schedule": "697A332A-697AA300,697B75F0-697B84AA",
        "phonePubKey": "BPmppi2q68FL7t74Yx8S7nH+71Cc4m96yeZh8HQZ03A+MBV96ITA3636Iu9TukRiXu38U/9Kf4qLP+tO2dbCdUE=",
        "permissions": ["unlock","overrideOverlock"]
    },
    "aclSignature": "MEQCIGgj0KsR6HVbUBf8uBbtduWxfTAz5rY9t2yyzthJKgdpAiByiTgw4C5gzsNTzcvhy4XDhO+fzc7IobIyW9DF4t1wEw=="
}
""".data(using: .utf8)!

do {
    let env = try JSONDecoder().decode(PhoneKeyAclEnvelope.self, from: sample)
    print("Decoded trackingId:", env.acl.trackingId ?? "<nil>") // "1"
    print("Schedule:", env.acl.schedule ?? "<nil>")
    print("Permissions.unlock:", env.acl.permissions.unlock) // true
    print("Signature algo:", env.acl.signature?.algorithm ?? "nil")
    // Re-encode back to the same shape (trackingId & schedule omitted if nil):
    let out = try JSONEncoder().encode(env)
    print(String(data: out, encoding: .utf8)!)
} catch {
    print("Decode/encode error:", error)
}
*/
