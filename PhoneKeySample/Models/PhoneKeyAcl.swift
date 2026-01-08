//
//  PhoneKeyAcl.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation


/// A resilient ISO‑8601 parser that supports Zulu UTC, offsets, and fractional seconds.
enum ISO8601 {
    /// Primary: supports fractional seconds and time zone offsets.
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0) // Dates should be absolute instants; keep in UTC internally
        return f
    }()
    
    /// Fallback: no fractional seconds.
    static let basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    /// Parse function used by decoders (tries fractional → basic).
    static func parse(_ s: String) -> Date? {
        if let d = withFractional.date(from: s) { return d }
        return basic.date(from: s)
    }
    
    /// Encoder counterpart that always emits RFC 3339/ISO‑8601 with fractional seconds.
    static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}

// MARK: - ISO8601 Utilities (UTC, with fractional seconds)
enum ISO8601Canonical {
    static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        // Precise, deterministic timestamps (UTC + fractional seconds)
        enc.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatted = withFractional.string(from: date)
            try container.encode(formatted)
        }
        // Stable: no .sortedKeys here (Apple’s built-in sortedKeys affects only Encoder’s *own* ordering).
        // We will sort after encoding using JSONSerialization.
        return enc
    }()

    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

// MARK: - JSON Sorting (stable key ordering)
func canonicalizeJSON(_ data: Data) throws -> Data {
    let obj = try JSONSerialization.jsonObject(with: data, options: [])
    let sorted = sortJSON(obj)
    return try JSONSerialization.data(withJSONObject: sorted, options: [])
}

private func sortJSON(_ any: Any) -> Any {
    switch any {
    case let dict as [String: Any]:
        let keys = dict.keys.sorted()
        var out: [String: Any] = [:]
        for k in keys { out[k] = sortJSON(dict[k]!) }
        return out
    case let arr as [Any]:
        // Arrays keep their order (canonicalization doesn’t sort arrays)
        return arr.map(sortJSON)
    default:
        return any
    }
}

struct PhoneKeyAcl: Codable {
    struct TimeWindow: Codable {
        let start: Date
        let end: Date
        
        private enum CodingKeys: String, CodingKey {
            case start
            case end
        }
        
        init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let startStr = try container.decode(String.self, forKey: .start)
            let endStr = try container.decode(String.self, forKey: .end)
            
            guard let startDate = ISO8601.parse(startStr) else {
                throw DecodingError.dataCorruptedError(forKey: .start, in: container, debugDescription: "Invalid ISO8601 date string: \(startStr)")
            }
            guard let endDate = ISO8601.parse(endStr) else {
                throw DecodingError.dataCorruptedError(forKey: .end, in: container, debugDescription: "Invalid ISO8601 date string: \(endStr)")
            }
            self.start = startDate
            self.end = endDate
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let startStr = ISO8601.string(from: start)
            let endStr = ISO8601.string(from: end)
            try container.encode(startStr, forKey: .start)
            try container.encode(endStr, forKey: .end)
        }
    }
    struct Permissions: Codable {
        let unlock: Bool
        let overrideOverlock: Bool
        let configWrite: Bool
        let fwUpdate: Bool
    }
    struct Meta: Codable {
        let ttlHours: Int
        let timeSource: String
        let hwType: String
    }
    struct Signature: Codable {
        let algorithm: String   // "Ed25519"
        let value: String       // Base64
    }
    
    let aclId: String
    let lockMac: String
    let phoneKeyId: String
    let phonePublicKey: String  // Base64 32 bytes
    let issuedAt: Date
    let expiresAt: Date
    let schedule: [TimeWindow]
    let permissions: Permissions
    let meta: Meta
    var signature: Signature
}

// Stripped ACL used only for canonicalization/signature creation (no `signature` field)
private struct ACLForCanonical: Codable {
    let aclId: String
    let lockMac: String
    let phoneKeyId: String
    let phonePublicKey: String
    let issuedAt: Date
    let expiresAt: Date
    let schedule: [PhoneKeyAcl.TimeWindow]
    let permissions: PhoneKeyAcl.Permissions
    let meta: PhoneKeyAcl.Meta
}

func canonicalize(acl: PhoneKeyAcl) throws -> Data {
    // Remove the signature object for signing
    let aclForCanonical = ACLForCanonical(
        aclId: acl.aclId,
        lockMac: acl.lockMac,
        phoneKeyId: acl.phoneKeyId,
        phonePublicKey: acl.phonePublicKey,
        issuedAt: acl.issuedAt,
        expiresAt: acl.expiresAt,
        schedule: acl.schedule,
        permissions: acl.permissions,
        meta: acl.meta
    )
    
    // Encode with canonical date format, then sort keys deterministically
    let raw = try ISO8601Canonical.encoder.encode(aclForCanonical)
    return try canonicalizeJSON(raw)
}

extension PhoneKeyAcl {
    func isCurrentlyAuthorized(now: Date = Date()) -> Bool {
        guard expiresAt > now else { return false }
        guard permissions.unlock else { return false }
        
        return schedule.contains { window in
            now >= window.start && now <= window.end
        }
    }
}
