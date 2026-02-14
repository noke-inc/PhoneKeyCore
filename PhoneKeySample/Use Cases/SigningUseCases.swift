//
//  SigningUseCases.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

public class SigningUseCases {
    public static func signCommand(with manager: PhoneKeyManager, base: PhoneKeySignedCommand) throws -> PhoneKeySignedCommand {
        let bytes = try canonicalCommandBytes(for: base)
        let signature = try manager.sign(bytes)
        let signedCommand = PhoneKeySignedCommand(commandId: base.commandId, signature: signature)
        return signedCommand
    }
    
    func canonicalize(acl: PhoneKeyAcl) throws -> Data {
        // Remove the signature object for signing
        let aclForCanonical = ACLForCanonical(acl: acl)
        
        // Encode with canonical date format, then sort keys deterministically
        let raw = try ISO8601Canonical.encoder.encode(aclForCanonical)
        return try SigningUseCases.canonicalizeJSON(raw)
    }
    
    public static func canonicalCommandBytes(for command: PhoneKeySignedCommand) throws -> Data {
        let commandForCanonical = CommandForCanonical(command: command)
        let raw = try ISO8601Canonical.encoder.encode(commandForCanonical)
        return try canonicalizeJSON(raw)
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
    
    private static func sortJSON(_ any: Any) -> Any {
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
    
    // MARK: - JSON Sorting (stable key ordering)
    static func canonicalizeJSON(_ data: Data) throws -> Data {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        let sorted = sortJSON(obj)
        return try JSONSerialization.data(withJSONObject: sorted, options: [])
    }
    
    private struct CommandForCanonical: Codable {
        let command: PhoneKeySignedCommand
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.command = try container.decode(PhoneKeySignedCommand.self, forKey: .command)
        }
        
        public init(command: PhoneKeySignedCommand) {
            self.command = command
        }
    }
    
    // Stripped ACL used only for canonicalization/signature creation (no `signature` field)
    private struct ACLForCanonical: Codable {
        let acl: PhoneKeyAcl
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.acl = try container.decode(PhoneKeyAcl.self, forKey: .acl)
        }
        
        public init(acl: PhoneKeyAcl) {
            self.acl = acl
        }
    }
}
