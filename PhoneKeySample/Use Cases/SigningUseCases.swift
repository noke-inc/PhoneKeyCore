//
//  SigningUseCases.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

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
