//
//  PhoneKey.swift
//  SmartEntryCore
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation
import Security
import Sodium
// CryptoKit exists in the SDK; guarded at use sites for iOS 13+
import CryptoKit

enum KeychainKeys {
    static let ed25519Seed = "ed25519.seed"
}

/// Signature algorithm (kept for future extensibility).
enum SignatureAlgorithm: String {
    case ed25519 = "Ed25519"
}

/// Unified key info for Ed25519 across OS versions
struct PhoneKeyInfo {
    let keyId: String
    let algorithm: SignatureAlgorithm
    let publicKeyRaw: Data
    let seed: Data
}

final class PhoneKeyManager {
    private let keychain: KeychainHelper
    private let sodium = Sodium()
    
    /// Cached key info (derived from seed).
    private(set) var keyInfo: PhoneKeyInfo?
    
    /// Initialize with existing KeychainHelper (service + optional access group).
    public init(serviceName: String, accessGroup: String? = nil) {
        let queryable = GenericPasswordQueryable(service: serviceName, accessGroup: accessGroup)
        self.keychain = KeychainHelper(keychainQueryable: queryable)
    }
    
    // MARK: Public API
    
    // Ensure an Ed25519 keypair exists, generating and storing one if needed.
    @discardableResult
    public func ensureKeys() throws -> PhoneKeyInfo {
        // 1) Try loading existing seed (Base64 string) via your helper
        if let base64 = try keychain.getValue(forKey: KeychainKeys.ed25519Seed), let seed = Data(base64Encoded: base64) {
            let pub = try derivePublicKey(fromSeed: seed)
            let existing = PhoneKeyInfo(keyId: keyIdFromSeed(seed), algorithm: .ed25519, publicKeyRaw: pub, seed: seed)
            self.keyInfo = existing
            return existing
        }
        
        // 2) Generate new 32-byte seed using libsodium CSPRNG
        guard let seedBytes = sodium.randomBytes.buf(length: 32) else {
            throw SEError(message: "Failed to generate Ed25519 seed.")
        }
        
        let seed = Data(seedBytes)
        
        // 3) Persist as Base64 string (uses your helper's setValue(_:forKey:))
        try keychain.setValue(seed.base64EncodedString(), forKey: KeychainKeys.ed25519Seed)
        
        // 4) Derive public key and return info
        let pub = try derivePublicKey(fromSeed: seed)
        let newKeyInfo = PhoneKeyInfo(keyId: keyIdFromSeed(seed), algorithm: .ed25519, publicKeyRaw: pub, seed: seed)
        self.keyInfo = newKeyInfo
        return newKeyInfo
    }
    
    /// Remove the seed from Keychain and clear cache.
    public func destroyKeys() throws {
        try keychain.removeValue(for: KeychainKeys.ed25519Seed)
        self.keyInfo = nil
    }
    
    /// Signs arbitrary data with Ed25519 using CryptoKit on iOS 13+ or Swift-Sodium otherwise.
    /// - Parameter data: The canonicalized bytes to sign.
    /// - Returns: 64-byte Ed25519 signature as Data.
    public func sign(_ data: Data) throws -> Data {
        let info = try self.keyInfo ?? ensureKeys()
        
        if #available(iOS 13.0, *) {
            // CryptoKit path: reconstruct from 32-byte seed
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: info.seed)
            let signature = try privateKey.signature(for: data)
            return signature
        } else {
            // Swift-Sodium path: derive secretKey from seed and sign
            guard let kp = sodium.sign.keyPair(seed: Array(info.seed)), let signature = sodium.sign.signature(message: Array(data), secretKey: kp.secretKey) else {
                throw SEError(message: "Failed to sign data with Ed25519.")
            }
            return Data(signature)
        }
    }
    
    
    func loadExistingKey(_ seed: Data) throws -> PhoneKeyInfo? {
        let pub = try derivePublicKey(fromSeed: seed)
        return PhoneKeyInfo(keyId: keyIdFromSeed(seed),
                            algorithm: .ed25519,
                            publicKeyRaw: pub,
                            seed: seed)
    }
    
    // MARK: - Helpers
    private func derivePublicKey(fromSeed seed: Data) throws -> Data {
        if #available(iOS 13.0, *) {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            let publicKey = privateKey.publicKey
            return publicKey.rawRepresentation
        } else {
            guard let kp = sodium.sign.keyPair(seed: Array(seed)) else {
                throw SEError(message: "Failed to derive Ed25519 keypair from seed.")
            }
            return Data(kp.publicKey)
        }
    }
    
    private func keyIdFromSeed(_ seed: Data) -> String {
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: seed)
            return uuidFromDigest(Data(digest))
        } else {
            guard let hash = sodium.genericHash.hash(message: Array(seed)) else {
                return uuidFromDigest(Data(Array(repeating: 0, count: 16)))
            }
            return uuidFromDigest(Data(hash))
        }
    }
    
    private func uuidFromDigest(_ data: Data) -> String {
        // Convert Data to [UInt8]
        var bytes: [UInt8] = Array(data)
        
        // Ensure we have at least 16 bytes (UUID requires 16)
        if bytes.count < 16 {
            bytes += Array(repeating: 0, count: 16 - bytes.count)
        }
        
        // Use only the first 16 bytes
        let u = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        
        return u.uuidString
    }
}
