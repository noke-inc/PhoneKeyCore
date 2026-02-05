//
//  PhoneKeyAclRequest.swift
//  PhoneKeyCore
//
//  Created by Joffrey Mann on 2/4/26.
//

import Foundation

public struct PhoneKeyAclRequest: Codable {
    public let userId: String      // normalized to String ("123")
    public let lockMac: String
    public let phoneKeyId: String  // normalized to String ("456")

    public init(userId: String, lockMac: String, phoneKeyId: String) {
        self.userId = userId
        self.lockMac = lockMac
        self.phoneKeyId = phoneKeyId
    }

    // Accept Int or String for userId and phoneKeyId; store both as String
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // userId
        if let s = try? container.decode(String.self, forKey: .userId) {
            self.userId = s.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let i = try? container.decode(Int.self, forKey: .userId) {
            self.userId = String(i)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                .init(codingPath: container.codingPath + [CodingKeys.userId],
                      debugDescription: "Expected userId as String or Int.")
            )
        }

        // lockMac
        self.lockMac = try container.decode(String.self, forKey: .lockMac)

        // phoneKeyId
        if let s = try? container.decode(String.self, forKey: .phoneKeyId) {
            self.phoneKeyId = s.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let i = try? container.decode(Int.self, forKey: .phoneKeyId) {
            self.phoneKeyId = String(i)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                .init(codingPath: container.codingPath + [CodingKeys.phoneKeyId],
                      debugDescription: "Expected phoneKeyId as String or Int.")
            )
        }
    }

    // Encode back as strings (no change)
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(lockMac, forKey: .lockMac)
        try container.encode(phoneKeyId, forKey: .phoneKeyId)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId
        case lockMac
        case phoneKeyId
    }
}
