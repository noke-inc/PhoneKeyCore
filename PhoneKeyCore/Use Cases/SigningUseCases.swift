//
//  SigningUseCases.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

func signACL(with manager: PhoneKeyManager, acl: PhoneKeyAcl) throws -> PhoneKeyAcl {
    // Phones typically do NOT sign ACLs (backend signs ACLs). Keep only if you need diagnostics.
    let bytes = try canonicalize(acl: acl)
    let signature = try manager.sign(bytes)
    var signedAcl = acl
    signedAcl.signature = .init(algorithm: SignatureAlgorithm.ed25519.rawValue, value: signature.base64EncodedString())
    return signedAcl
}

func signCommand(with manager: PhoneKeyManager, base: PhoneKeySignedCommand) throws -> PhoneKeySignedCommand {
    let bytes = try canonicalCommandBytes(for: base)
    let signature = try manager.sign(bytes)
    var signedCommand = base
    signedCommand.signature = .init(algorithm: SignatureAlgorithm.ed25519.rawValue, value: signature.base64EncodedString())
    return signedCommand
}

func canonicalize(acl: PhoneKeyAcl) throws -> Data {
    // Remove the signature object for signing
    let aclForCanonical = ACLForCanonical(acl: acl)
    
    // Encode with canonical date format, then sort keys deterministically
    let raw = try ISO8601Canonical.encoder.encode(aclForCanonical)
    return try canonicalizeJSON(raw)
}

public func canonicalCommandBytes(for command: PhoneKeySignedCommand) throws -> Data {
    let commandForCanonical = CommandForCanonical(command: command)
    let raw = try ISO8601Canonical.encoder.encode(commandForCanonical)
    return try canonicalizeJSON(raw)
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
