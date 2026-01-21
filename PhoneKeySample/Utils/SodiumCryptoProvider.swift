
//
//  SodiumCryptoProvider.swift
//  PhoneKeySample
//
//  Created by Joffrey Mann on 1/21/26.
//

import Foundation
import Sodium
import PhoneKeyCore
import CommonCrypto

final class SodiumCryptoProvider: CryptoProvider {

    private let sodium = Sodium()

    // MARK: - Ed25519 Seed (32 bytes)
    func generateEd25519Seed() throws -> Data {
        // Ed25519 seed size is always 32 bytes
        guard let seed = sodium.randomBytes.buf(length: 32) else {
            throw NSError(domain: "Crypto", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to generate Ed25519 seed"])
        }
        return Data(seed)
    }

    // MARK: - Public key from seed (deterministic)
    func derivePublicKey(fromSeed seed: Data) throws -> Data {
        guard let kp = sodium.sign.keyPair(seed: Array(seed)) else {
            throw NSError(domain: "Crypto", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to derive keypair from seed"])
        }
        return Data(kp.publicKey)  // 32 bytes
    }

    // MARK: - Sign message with seed
    func sign(message: Data, withSeed seed: Data) throws -> Data {
        guard let kp = sodium.sign.keyPair(seed: Array(seed)),
              let sig = sodium.sign.signature(message: Array(message),
                                              secretKey: kp.secretKey)
        else {
            throw NSError(domain: "Crypto", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to sign Ed25519 message"])
        }
        return Data(sig)  // 64 bytes
    }

    // MARK: - SHA-256 (must match CryptoKit)
    func getHash(of data: Data) throws -> Data {
        return sha256CC(data)
    }
}

// MARK: - SHA‑256 using CommonCrypto (correct)
private func sha256CC(_ data: Data) -> Data {
    var digest = [UInt8]()
    data.withUnsafeBytes { buffer in
        _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest)   // 32 bytes
}
