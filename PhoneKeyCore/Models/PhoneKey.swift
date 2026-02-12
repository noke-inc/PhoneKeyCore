//
//  PhoneKey.swift
//  SmartEntryCore
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation
import Security
// CryptoKit exists in the SDK; guarded at use sites for iOS 13+
import CryptoKit

public enum KeychainKeys {
    static let ed25519Seed = "ed25519.seed"
    // NEW: persistent tag to store P-256 SecKey in Keychain
    static let p256PrivateKeyTag = "p256.signing.privatekey"
}

/// Signature algorithm (kept for future extensibility).
public enum SignatureAlgorithm: String, Codable {
    case ed25519 = "Ed25519"
    case ecdsaP256 = "ECDSA_P256" // NEW
}

public enum PhoneKeyStatus: String, Codable {
    case active = "active"
    case revoked = "revoked"
    case expired = "expired"
}

public protocol CryptoProvider: AnyObject {
    func generateEd25519Seed() throws -> Data
    func derivePublicKey(fromSeed seed: Data) throws -> Data
    func sign(message: Data, withSeed seed: Data) throws -> Data
    func getHash(of data: Data) throws -> Data
}

/// Unified key info for Ed25519 across OS versions; extended for P-256 via keyTag
public struct PhoneKeyInfo: Codable {
    public let keyId: String
    public let algorithm: SignatureAlgorithm
    public let publicKeyRaw: Data  // Ed25519: 32 bytes; P-256: 65 bytes (0x04 || X || Y)
    public let seed: Data          // Ed25519: 32-byte seed; P-256: unused/empty (kept for compatibility)
    public var status: PhoneKeyStatus
    // NEW: for P-256 SecKey lookup (application tag used to store/find in Keychain)
    public let keyTag: Data? = nil
}

public final class PhoneKeyManager {
    private let keychain: KeychainHelper
    private var provider: CryptoProvider?
    private let serviceName: String
    private let accessGroup: String? // NEW: keep access group for SecKey creation
    private let preferredAlgorithm: SignatureAlgorithm // NEW

    /// Cached key info (derived from seed for Ed25519; from SecKey for P-256)
    private(set) var keyInfo: PhoneKeyInfo?

    /// Initialize with existing KeychainHelper (service + optional access group).
    public init(serviceName: String,
                accessGroup: String? = nil,
                provider: CryptoProvider?,
                preferredAlgorithm: SignatureAlgorithm = .ecdsaP256) { // NEW default
        let queryable = GenericPasswordQueryable(
            service: KeychainHelper.nokeKeychainService,    // stable base
            accessGroup: nil,                                // keep nil for app-scoped items
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
        self.keychain = KeychainHelper(keychainQueryable: queryable)
        self.serviceName = serviceName
        self.provider = provider
        self.accessGroup = accessGroup
        self.preferredAlgorithm = preferredAlgorithm
    }

    // MARK: Public API

    /// Ensure a keypair exists for the preferred algorithm. Backward compatible with Ed25519-only flow.
    @discardableResult
    public func ensureKeys() throws -> PhoneKeyInfo {
        return try ensureKeys(algorithm: preferredAlgorithm)
    }

    /// Ensure a keypair exists for the requested algorithm.
    @discardableResult
    public func ensureKeys(algorithm: SignatureAlgorithm) throws -> PhoneKeyInfo {
        switch algorithm {
        case .ed25519:
            return try ensureEd25519Keys()
        case .ecdsaP256:
            return try ensureP256Keys()
        }
    }

    // MARK: - Ed25519 path (unchanged behavior)

    @discardableResult
    private func ensureEd25519Keys() throws -> PhoneKeyInfo {
        // 1. Try loading existing seed from Keychain
        if let base64 = try keychain.getValue(forKey: KeychainKeys.ed25519Seed),
           let seed = Data(base64Encoded: base64) {

            let pub = try derivePublicKeyEd25519(fromSeed: seed)

            let existing = PhoneKeyInfo(
                keyId: keyIdFromEd25519Seed(seed),
                algorithm: .ed25519,
                publicKeyRaw: pub,
                seed: seed,
                status: .active
            )

            self.keyInfo = existing
            return existing
        }

        // 2. We need to generate a new seed. Provider MUST exist.
        guard let provider = provider else {
            throw SEPhoneKeyError.cryptoProviderNotSet()
        }

        // 3. Generate fresh Ed25519 seed (32 bytes)
        let seed = try provider.generateEd25519Seed()

        // 4. Save to Keychain (Base64)
        try keychain.setValue(seed.base64EncodedString(), forKey: KeychainKeys.ed25519Seed)

        // 5. Derive public key from seed
        let pub = try derivePublicKeyEd25519(fromSeed: seed)

        let newKeyInfo = PhoneKeyInfo(
            keyId: keyIdFromEd25519Seed(seed),
            algorithm: .ed25519,
            publicKeyRaw: pub,
            seed: seed,
            status: .active
        )

        self.keyInfo = newKeyInfo
        return newKeyInfo
    }

    // MARK: - NEW: ECDSA P-256 path

    /// Ensures a P-256 ECDSA signing key exists in the Keychain (SecKey), derives public key in X9.63 format.
    @discardableResult
    private func ensureP256Keys() throws -> PhoneKeyInfo {
        // Attempt to load existing private key by tag
        let tagData = Data(KeychainKeys.p256PrivateKeyTag.utf8)
        if let privateKey = try fetchExistingP256PrivateKey(tag: tagData) {
            let pubRaw = try exportP256PublicKeyRaw(privateKey: privateKey)
            let keyId = keyIdFromPublicKey(pubRaw)
            let info = PhoneKeyInfo(
                keyId: keyId,
                algorithm: .ecdsaP256,
                publicKeyRaw: pubRaw,
                seed: Data(), // unused for P-256; kept empty for compatibility
                status: .active
            )
            self.keyInfo = info
            return info
        }

        // Generate a new P-256 key and store in Keychain (permanent)
        let privateKey = try generateP256PrivateKey(tag: tagData, accessGroup: accessGroup)
        let pubRaw = try exportP256PublicKeyRaw(privateKey: privateKey)
        let keyId = keyIdFromPublicKey(pubRaw)

        let info = PhoneKeyInfo(
            keyId: keyId,
            algorithm: .ecdsaP256,
            publicKeyRaw: pubRaw,
            seed: Data(), // unused for P-256
            status: .active
        )
        self.keyInfo = info
        return info
    }

    /// Remove the Ed25519 seed from Keychain and clear cache.
    public func destroyKeys() throws {
        try keychain.removeValue(for: KeychainKeys.ed25519Seed)
        // Also attempt to delete P-256 key (no-throw if not found)
        try? deleteP256Key()
        self.keyInfo = nil
    }

    /// Signs arbitrary data with the current or preferred algorithm.
    /// - Parameter data: The canonicalized bytes to sign.
    /// - Parameter algorithm: Optional override; defaults to ensure (preferred) keys.
    /// - Returns: Signature bytes (Ed25519: 64; P-256: 64 raw r||s).
    public func sign(_ data: Data, algorithm: SignatureAlgorithm? = nil) throws -> Data {
        let info = try self.keyInfo ?? ensureKeys(algorithm: algorithm ?? preferredAlgorithm)

        switch info.algorithm {
        case .ed25519:
            if #available(iOS 13.0, *) {
                // CryptoKit path: reconstruct from 32-byte seed
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: info.seed)
                let signature = try privateKey.signature(for: data)
                return signature
            } else {
                // Swift-Sodium path: derive secretKey from seed and sign
                guard let provider = provider else {
                    throw SEPhoneKeyError.cryptoProviderNotSet()
                }
                do {
                    return try provider.sign(message: data, withSeed: info.seed)
                } catch {
                    throw SEPhoneKeyError.failedToSignData()
                }
            }

        case .ecdsaP256:
            // Prefer Security (SecKey) so the key stays in the Keychain.
            let tagData = Data(KeychainKeys.p256PrivateKeyTag.utf8)
            guard let privateKey = try fetchExistingP256PrivateKey(tag: tagData) else {
                throw SEPhoneKeyError.failedToSignData() // shouldn't happen since ensureKeys() ran
            }
            // Create DER-encoded ECDSA signature, then convert to raw 64 bytes (r||s)
            let derSig = try signP256WithSecKey(privateKey: privateKey, message: data)
            let raw64 = try ecdsaSignatureDERToRawRS(der: derSig, componentSize: 32)
            return raw64
        }
    }

    public func loadExistingKey(_ seed: Data) throws -> PhoneKeyInfo? {
        // Backward compatibility: Ed25519 only
        let pub = try derivePublicKeyEd25519(fromSeed: seed)
        return PhoneKeyInfo(keyId: keyIdFromEd25519Seed(seed),
                            algorithm: .ecdsaP256,
                            publicKeyRaw: pub,
                            seed: seed,
                            status: .active)
    }

    // Soft-expire: mark status and/or expiry timestamp (POC only)
    public func expireCurrentKeyPOC(expiresAt: Date? = Date()) {
        guard var info = self.keyInfo else {
            return
        }
        info.status = .expired
        self.keyInfo = info
    }

    // Soft-revoke (POC): status revoked
    public func revokeCurrentKeyPOC(reason: String? = nil) {
        guard var info = self.keyInfo else {
            return
        }
        info.status = .revoked
        self.keyInfo = info
    }

    // Hard-expire: delete seed and derived keys (from earlier guidance)
    func deleteAllKeys() throws {
        try deleteSeed()
        try? deleteP256Key()
        self.keyInfo = nil
    }

    public func deleteSeed() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "ed25519.seed"
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }

    // NEW: Delete P-256 SecKey by tag
    public func deleteP256Key() throws {
        let tagData = Data(KeychainKeys.p256PrivateKeyTag.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tagData
        ]
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }

    // MARK: - Helpers

    // Ed25519 public derivation
    private func derivePublicKeyEd25519(fromSeed seed: Data) throws -> Data {
        if #available(iOS 13.0, *) {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            let publicKey = privateKey.publicKey
            return publicKey.rawRepresentation
        } else {
            do {
                guard let provider = provider else {
                    throw SEPhoneKeyError.cryptoProviderNotSet()
                }
                return try provider.derivePublicKey(fromSeed: seed)
            } catch {
                throw SEPhoneKeyError.failedToDerivePublicKey()
            }
        }
    }

    private func keyIdFromEd25519Seed(_ seed: Data) -> String {
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: seed)
            return uuidFromDigest(Data(digest))
        } else {
            guard let provider = provider, let hash = try? provider.getHash(of: seed) else {
                return uuidFromDigest(Data(Array(repeating: 0, count: 16)))
            }
            return uuidFromDigest(Data(hash))
        }
    }

    private func keyIdFromPublicKey(_ pubRaw: Data) -> String {
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: pubRaw)
            return uuidFromDigest(Data(digest))
        } else {
            // SHA-256 via CommonCrypto could be added; reuse Ed25519 provider if present
            if let provider = provider, let hash = try? provider.getHash(of: pubRaw) {
                return uuidFromDigest(Data(hash))
            }
            return uuidFromDigest(Data(Array(repeating: 0, count: 16)))
        }
    }

    private func uuidFromDigest(_ data: Data) -> String {
        var bytes: [UInt8] = Array(data)
        if bytes.count < 16 { bytes += Array(repeating: 0, count: 16 - bytes.count) }
        let u = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return u.uuidString
    }

    // MARK: - P-256 Security helpers

    private func fetchExistingP256PrivateKey(tag: Data) throws -> SecKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true
        ]
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status))
        }

        // Success path: item must be a SecKey
        return (item as! SecKey)
    }

    private func generateP256PrivateKey(tag: Data, accessGroup: String?) throws -> SecKey {
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag
            ]
        ]
        if let accessGroup = accessGroup {
            var privAttrs = attributes[kSecPrivateKeyAttrs as String] as! [String: Any]
            privAttrs[kSecAttrAccessGroup as String] = accessGroup
            attributes[kSecPrivateKeyAttrs as String] = privAttrs
        }
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw (error?.takeRetainedValue() as Error?) ?? SEPhoneKeyError.failedToDerivePublicKey()
        }
        return privateKey
    }

    /// Export P-256 public key in X9.63 (uncompressed, 65 bytes: 0x04 || X || Y)
    private func exportP256PublicKeyRaw(privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SEPhoneKeyError.failedToDerivePublicKey()
        }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw (error?.takeRetainedValue() as Error?) ?? SEPhoneKeyError.failedToDerivePublicKey()
        }
        return data
    }

    /// Sign with SecKey using ECDSA + SHA-256; returns DER-encoded signature
    private func signP256WithSecKey(privateKey: SecKey, message: Data) throws -> Data {
        let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw SEPhoneKeyError.failedToSignData()
        }
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, message as CFData, &error) as Data? else {
            throw (error?.takeRetainedValue() as Error?) ?? SEPhoneKeyError.failedToSignData()
        }
        return signature
    }

    /// Convert ASN.1 DER ECDSA signature to raw (r||s), each component fixed-width
    private func ecdsaSignatureDERToRawRS(der: Data, componentSize: Int) throws -> Data {
        // Very small ASN.1 parser for SEQUENCE { INTEGER r; INTEGER s }
        var idx = 0
        func readByte() throws -> UInt8 {
            guard idx < der.count else { throw SEPhoneKeyError.failedToSignData() }
            let b = der[idx]; idx += 1; return b
        }
        func readLength() throws -> Int {
            let first = try readByte()
            if first & 0x80 == 0 { return Int(first) }
            let count = Int(first & 0x7F)
            guard count > 0 && count <= 4 && idx + count <= der.count else { throw SEPhoneKeyError.failedToSignData() }
            var len = 0
            for _ in 0..<count { len = (len << 8) | Int(try readByte()) }
            return len
        }
        func readInteger() throws -> Data {
            guard try readByte() == 0x02 else { throw SEPhoneKeyError.failedToSignData() }
            let len = try readLength()
            guard idx + len <= der.count else { throw SEPhoneKeyError.failedToSignData() }
            let bytes = der[idx..<(idx+len)]; idx += len
            // Strip possible leading 0x00 padding and left-pad to componentSize
            let trimmed = Data(bytes.drop(while: { $0 == 0x00 }).suffix(componentSize)) // cap to componentSize
            if trimmed.count > componentSize { throw SEPhoneKeyError.failedToSignData() }
            return Data(repeating: 0, count: componentSize - trimmed.count) + trimmed
        }

        guard try readByte() == 0x30 else { throw SEPhoneKeyError.failedToSignData() }
        _ = try readLength()
        let r = try readInteger()
        let s = try readInteger()
        return r + s
    }
}

// MARK: - ACL Chunking / Signing
public extension PhoneKeyManager {

    /// Build a signed ACL payload and return it chunked into 128-byte hex packets.
    ///
    /// - Parameters:
    ///   - acl: Raw ACL bytes (NOT including signature).
    ///   - algorithm: Which algorithm to use (default = preferred).
    /// - Returns: Array of hex strings (each packet = header + payload).
    ///
    /// The format required by the lock:
    ///   • Chunk 0..N-1:   "NN" + 128 hex bytes
    ///   • Final chunk:    "xx" + 4 hex digits of total ACL length (ACL only, not including signature)
    ///   • Signature:      Appended after ACL:
    ///         - Ed25519: 64 bytes
    ///         - ECDSA P-256: 64 bytes raw (r||s)
    ///
    func buildACLChunks(acl: Data, algorithm: SignatureAlgorithm? = nil) throws -> [String] {

        // 1. Ensure keys exist
        let keyInfo = try ensureKeys(algorithm: algorithm ?? preferredAlgorithm)

        // 2. Compute signature over entire ACL
        let signature = try sign(acl, algorithm: keyInfo.algorithm)

        // 3. Final payload = ACL + signature (length depends on algorithm)
        var fullPayload = Data()
        fullPayload.append(acl)
        fullPayload.append(signature)

        // 4. Chunking parameters
        let chunkSize = 128
        let totalLen = acl.count    // IMPORTANT: spec says "length of ACL only"
        let chunkCount = Int(ceil(Double(fullPayload.count) / Double(chunkSize)))

        var result: [String] = []

        for chunkIndex in 0..<chunkCount {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, fullPayload.count)

            let chunkBytes = fullPayload[start..<end]
            let hexPayload = chunkBytes.map { String(format:"%02x", $0) }.joined()

            if chunkIndex < chunkCount - 1 {
                // Normal chunk: "00", "01", ...
                let header = String(format: "%02x", chunkIndex)
                print("Current header: \(header)")
                print("Current header length: \(header.count)")
                result.append(header + hexPayload)
            } else {
                // FINAL chunk: "xx" + 4 hex digits of ACL length
                let lengthField = String(format: "%04x", totalLen)
                let header = "xx" + lengthField
                print("Current header: \(header)")
                print("Current header length: \(header.count)")
                result.append(header + hexPayload)
            }
        }

        return result
    }
}

// MARK: - ACL Local Persistence (Keychain) – Non-invasive CRUD (strengthened)

public extension PhoneKeyManager {

    // MARK: - Namespacing & Constants

    private enum ACLStoreKeys {
        static let index = "acl.index"                 // JSON array of trackingIds
        static func item(_ trackingId: String) -> String { "acl.item.\(trackingId)" }
    }

    private enum ACLError: LocalizedError {
        case missingTrackingId
        case identicalIds
        case notFound
        case migrateNeedsSourceId
        case invalidId

        var errorDescription: String? {
            switch self {
            case .missingTrackingId:
                return "ACL must have a non-empty 'trackingId' for this operation."
            case .identicalIds:
                return "Source and destination trackingId are identical; nothing to migrate."
            case .notFound:
                return "ACL not found for the given trackingId."
            case .migrateNeedsSourceId:
                return "Migration requires a valid source trackingId."
            case .invalidId:
                return "Invalid trackingId."
            }
        }
    }

    // MARK: - Encoders

    /// Dedicated encoder/decoder for ACL JSON (epoch seconds are handled by PhoneKeyAcl itself).
    private var aclEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [] // compact (deterministic layout comes from the model)
        return e
    }
    private var aclDecoder: JSONDecoder { JSONDecoder() }

    // MARK: - Public CRUD

    /// Save (create or replace) an ACL by `trackingId`.
    /// Requires a **non-empty `trackingId`** (server or temp).
    func saveACLEnvelope(_ aclEnvelope: PhoneKeyAclEnvelope) throws {
        let trackingId = normalize(aclEnvelope.acl.trackingId)
        guard !trackingId.isEmpty else {
            throw ACLError.missingTrackingId
        }
        // 1) Serialize ACL
        let data = try aclEncoder.encode(aclEnvelope)

        // 2) Persist item
        let itemKey = ACLStoreKeys.item(trackingId)
        try keychain.setValue(data.base64EncodedString(), forKey: itemKey)

        // 3) Update index (dedupe)
        var index = try loadACLIndex()
        if !index.contains(trackingId) {
            index.append(trackingId)
            try storeACLIndex(index)
        }
    }

    /// Upsert with optional merge. Requires a **non-empty** trackingId.
    @discardableResult
    func updateACL(_ updatedEnvelope: PhoneKeyAclEnvelope,
                   merge: ((PhoneKeyAclEnvelope) -> PhoneKeyAclEnvelope)? = nil) throws -> PhoneKeyAclEnvelope {
        let trackingId = normalize(updatedEnvelope.acl.trackingId)
        guard !trackingId.isEmpty else {
            throw ACLError.missingTrackingId
        }
        if let existing = try getACLEnvelope(trackingId: trackingId), let merge = merge {
            let merged = merge(existing)
            try saveACLEnvelope(merged)
            return merged
        } else {
            try saveACLEnvelope(updatedEnvelope)
            return updatedEnvelope
        }
    }

    /// Fetch an ACL by `trackingId` (server or temp).
    func getACLEnvelope(trackingId: String) throws -> PhoneKeyAclEnvelope? {
        let id = normalize(trackingId)
        let itemKey = ACLStoreKeys.item(id)
        guard let b64 = try keychain.getValue(forKey: itemKey),
              let data = Data(base64Encoded: b64) else {
            return nil
        }
        return try aclDecoder.decode(PhoneKeyAclEnvelope.self, from: data)
    }

    /// Delete an ACL by `trackingId`. No-op if not found.
    func deleteACL(trackingId: String) throws {
        let id = normalize(trackingId)
        let itemKey = ACLStoreKeys.item(id)
        try keychain.removeValue(for: itemKey)

        var index = try loadACLIndex()
        if let i = index.firstIndex(of: id) {
            index.remove(at: i)
            try storeACLIndex(index)
        }
    }

    /// Return all stored ACLs (best-effort: skips items that fail to decode).
    func listACLEnvelopes() throws -> [PhoneKeyAclEnvelope] {
        let ids = try loadACLIndex()
        var out: [PhoneKeyAclEnvelope] = []
        out.reserveCapacity(ids.count)

        for id in ids {
            if let aclEnvelope = try getACLEnvelope(trackingId: id) {
                out.append(aclEnvelope)
            } else {
                // If an item is missing/corrupt, drop it from index (self-healing).
                try removeIdFromIndex(id)
            }
        }
        return out
    }
    
    // MARK: - New: Save Phone Key Info
    
    /// Persist the current PhoneKeyInfo (if any) under a reserved key.
    /// This allows the app to recover key info (e.g., after a relaunch) and a reinstall depending on the accessibility flag.
    func savePhoneKeyInfo(info: PhoneKeyInfoResponse) throws {
        let data = try JSONEncoder().encode(info)
        try keychain.setValue(data.base64EncodedString(), forKey: "phoneKeyInfo")
    }
    
    // MARK: - New: Load Phone Key Info
    
    /// Load the persisted PhoneKeyInfo (if any) from the reserved key.
    /// Returns nil if not found or if decoding fails (e.g., due to corruption or format change).
    
    func getPhoneKeyInfo() throws -> PhoneKeyInfoResponse? {
        guard let b64 = try? keychain.getValue(forKey: "phoneKeyInfo"),
              let data = Data(base64Encoded: b64) else {
            return nil
        }
        return try? JSONDecoder().decode(PhoneKeyInfoResponse.self, from: data)
    }

    // MARK: - New: Save with Temporary ID (for server-less drafts)

    /// Persist an ACL that may not yet have a server-assigned trackingId.
    /// - Returns: The **trackingId used for persistence** (server id if present; otherwise a generated temp id).
    @discardableResult
    func saveACLOrAssignTempId(_ aclEnvelope: PhoneKeyAclEnvelope) throws -> String {
        let serverId = normalize(aclEnvelope.acl.trackingId)
        if !serverId.isEmpty {
            try saveACLEnvelope(aclEnvelope)
            return serverId
        }
        
        let acl = aclEnvelope.acl

        // Create a temp id and persist a copy of the ACL under that id.
        let tempId = makeTempTrackingId()
        let draft = PhoneKeyAcl(
            trackingId: tempId,
            lockMac: acl.lockMac,
            phonePublicKey: acl.phonePublicKey,
            issuedAt: acl.issuedAt,
            expiresAt: acl.expiresAt,
            schedule: acl.schedule,                  // may be nil
            permissions: acl.permissions,
            //signature: acl.signature
        )
        try saveACLEnvelope(aclEnvelope)
        return tempId
    }

    // MARK: - New: Migration from temp -> server trackingId

    /// Migrate a stored ACL from a **temporary** trackingId to a **server** trackingId.
    /// - Parameters:
    ///   - fromTempId: the existing temp id (e.g., "temp:...").
    ///   - toServerId: the definitive server id (non-empty).
    /// - Behavior:
    ///   1) Loads temp item; 2) re-saves under server id with `trackingId` updated in the payload;
    ///   3) removes the temp item; 4) updates index atomically.
    func migrateACLTrackingId(fromTempId: String, toServerId: String) throws {
        let fromId = normalize(fromTempId)
        let toId = normalize(toServerId)

        guard !fromId.isEmpty else { throw ACLError.migrateNeedsSourceId }
        guard !toId.isEmpty else { throw ACLError.invalidId }
        guard fromId != toId else { throw ACLError.identicalIds }

        guard var aclEnvelope = try getACLEnvelope(trackingId: fromId) else { throw ACLError.notFound }
        
        let acl = aclEnvelope.acl

        // Rebuild with the new server trackingId
        let migrated = PhoneKeyAcl(
            trackingId: toId,
            lockMac: acl.lockMac,
            phonePublicKey: acl.phonePublicKey,
            issuedAt: acl.issuedAt,
            expiresAt: acl.expiresAt,
            schedule: acl.schedule,
            permissions: acl.permissions,
            //signature: acl.signature
        )
        aclEnvelope.acl = migrated

        // Save new, then delete old; update index accordingly
        try saveACLEnvelope(aclEnvelope)
        try deleteACL(trackingId: fromId)
    }

    // MARK: - Index helpers

    private func loadACLIndex() throws -> [String] {
        if let b64 = try keychain.getValue(forKey: ACLStoreKeys.index),
           let data = Data(base64Encoded: b64),
           let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
            // Ensure unique + normalized ids in memory
            let unique = Array(Set(array.map(normalize))).sorted()
            return unique
        }
        return []
    }

    private func storeACLIndex(_ ids: [String]) throws {
        // Store unique + normalized ids
        let unique = Array(Set(ids.map(normalize))).sorted()
        let data = try JSONSerialization.data(withJSONObject: unique, options: [])
        try keychain.setValue(data.base64EncodedString(), forKey: ACLStoreKeys.index)
    }

    private func removeIdFromIndex(_ trackingId: String) throws {
        var index = try loadACLIndex()
        if let i = index.firstIndex(of: trackingId) {
            index.remove(at: i)
            try storeACLIndex(index)
        }
    }

    // MARK: - Utilities

    /// Normalize ids (trim whitespace). Keep case as-is (server-defined).
    private func normalize(_ id: String?) -> String {
        (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `temp:` + UUID – avoids collisions with numeric server ids and makes intent explicit.
    private func makeTempTrackingId() -> String {
        "temp:\(UUID().uuidString)"
    }

    /// Public helper if callers need to check whether an id is client-generated.
    func isTempTrackingId(_ id: String) -> Bool {
        normalize(id).hasPrefix("temp:")
    }
}
