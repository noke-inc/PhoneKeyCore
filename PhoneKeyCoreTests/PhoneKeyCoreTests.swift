//
//  PhoneKeyCoreTests.swift
//  PhoneKeyCoreTests
//
//  Created by Joffrey Mann on 1/20/26.
//

import XCTest
@testable import PhoneKeyCore


final class MockCryptoProvider: CryptoProvider {

    let seed: Data
    let pub: Data
    let hash: Data
    let signature: Data

    init(seed: Data, pub: Data, hash: Data, signature: Data) {
        self.seed = seed
        self.pub = pub
        self.hash = hash
        self.signature = signature
    }

    func generateEd25519Seed() throws -> Data {
        return seed
    }

    func derivePublicKey(fromSeed seed: Data) throws -> Data {
        return pub
    }

    func sign(message: Data, withSeed seed: Data) throws -> Data {
        return signature
    }

    func getHash(of data: Data) throws -> Data {
        return hash
    }

    func getRandomBytes(count: Int) throws -> Data {
        return seed
    }
}


final class PhoneKeyCoreTests: XCTestCase {
    func testEnsureKeysGeneratesNewKey() throws {
        let seed = Data(repeating: 0xAA, count: 32)
        let pub  = Data(repeating: 0xBB, count: 32)
        let hash = Data(repeating: 0xCC, count: 32)
        let sig  = Data(repeating: 0xDD, count: 64)

        let provider = MockCryptoProvider(seed: seed, pub: pub, hash: hash, signature: sig)
        let mgr = PhoneKeyManager(serviceName: "test.ensureKeys", provider: provider)

        let info = try mgr.ensureKeys()

        XCTAssertEqual(info.seed, seed)
        XCTAssertEqual(info.publicKeyRaw.count, pub.count)
        XCTAssertEqual(info.algorithm, .ed25519)
        XCTAssertEqual(info.status, .active)
    }

    func testEnsureKeysIsIdempotent() throws {
        let seed = Data(repeating: 0x11, count: 32)
        let pub  = Data(repeating: 0x22, count: 32)
        let hash = Data(repeating: 0x33, count: 32)
        let sig  = Data(repeating: 0x44, count: 64)

        let provider = MockCryptoProvider(seed: seed, pub: pub, hash: hash, signature: sig)
        let mgr = PhoneKeyManager(serviceName: "test.idempotent", provider: provider)

        let first = try mgr.ensureKeys()
        let second = try mgr.ensureKeys()

        XCTAssertEqual(first.seed, second.seed)
        XCTAssertEqual(first.publicKeyRaw, second.publicKeyRaw)
        XCTAssertEqual(first.keyId, second.keyId)
    }
    
    func testKeyIdDeterministic() throws {
        let seed = Data(repeating: 0x55, count: 32)
        let pub  = Data(repeating: 0x66, count: 32)
        let hash = Data(repeating: 0x77, count: 32)
        let sig  = Data(repeating: 0x88, count: 64)

        let provider = MockCryptoProvider(seed: seed, pub: pub, hash: hash, signature: sig)
        let mgr = PhoneKeyManager(serviceName: "test.keyid", provider: provider)

        let info1 = try mgr.ensureKeys()
        let info2 = try mgr.ensureKeys()

        XCTAssertEqual(info1.keyId, info2.keyId)
    }
    
    func testDestroyKeysRemovesSeed() throws {
        let seed = Data(repeating: 0x01, count: 32)
        let pub  = Data(repeating: 0x02, count: 32)
        let hash = Data(repeating: 0x03, count: 32)
        let sig  = Data(repeating: 0x04, count: 64)

        let provider = MockCryptoProvider(seed: seed, pub: pub, hash: hash, signature: sig)
        let mgr = PhoneKeyManager(serviceName: "test.destroy", provider: provider)

        _ = try mgr.ensureKeys()

        try mgr.destroyKeys()

        // should force new seed
        let newInfo = try mgr.ensureKeys()
        XCTAssertEqual(newInfo.seed, seed) // because mock always returns the same seed
    }
    
    func testSaveBulkACLs() throws {
        let seed = Data(repeating: 0x01, count: 32)
        let pub  = Data(repeating: 0x02, count: 32)
        let hash = Data(repeating: 0x03, count: 32)
        let sig  = Data(repeating: 0x04, count: 64)
        
        let provider = MockCryptoProvider(seed: seed, pub: pub, hash: hash, signature: sig)
        
        let mgr = PhoneKeyManager(serviceName: "test.acl", provider: provider)
        let now = Date()
        let mockBulkACL = BulkPhoneKeyAcl(
            result: "success",
            lockMac: "AA:BB:CC:DD:EE:FF",
            aclBinary: "mockBinaryData",
            aclSignature: sig.base64EncodedString(),
            issuedAt: now,
            expiresAt: now.addingTimeInterval(86400),
            storedAt: now
        )
        try mgr.saveBulkACLs(userId: "testUser", [mockBulkACL])
        let acls = try mgr.getBulkACLs(userId: "testUser")
        XCTAssertNotNil(acls)
        XCTAssertEqual(acls?.count, 1)
        XCTAssertEqual(acls?.first?.aclSignature, sig.base64EncodedString())
        XCTAssertEqual(acls?.first?.lockMac, "AA:BB:CC:DD:EE:FF")
    }
}
