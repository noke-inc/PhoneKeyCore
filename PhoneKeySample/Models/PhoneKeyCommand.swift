//
//  PhoneKeyCommand.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

struct PhoneKeySignedCommand: Codable {
    struct Signature: Codable {
        let algorithm: String       // "Ed25519"
        let value: String           // Base64
    }
    let commandId: String
    let type: String
    let createdAt: String
    let nonce: String       // Base64 16-32 bytes
    let payload: [String: String]
    var signature: Signature
}

private struct CommandForCanonical: Codable {
    let commandId: String
    let type: String
    let createdAt: String
    let nonce: String
    let payload: [String: String]
}

func canonicalCommandBytes(for command: PhoneKeySignedCommand) throws -> Data {
    let commandForCanonical = CommandForCanonical(
        commandId: command.commandId,
        type: command.type,
        createdAt: command.createdAt,
        nonce: command.nonce,
        payload: command.payload
    )
    let raw = try ISO8601Canonical.encoder.encode(commandForCanonical)
    return try canonicalizeJSON(raw)
}
