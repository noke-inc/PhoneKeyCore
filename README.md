**📱🔐 PhoneKeyCore + Sample App
Unified Phone‑Key Generation, ACL Handling, Command Signing & Demo UI**

This repository contains:

PhoneKeyCore — a standalone framework that handles:

Phone‑key generation & storage
Ed25519 and ECDSA P‑256 signing
ACL decoding, canonicalization, signing & chunking
JSON & ISO‑8601 utilities
Lock‑compatible ACL storage in Keychain


PhoneKeySample App — an end‑to‑end demonstration showing:

How to ensure/load a phone key
How to send your public key to your backend
How to build, canonicalize & sign unlock commands
How to test key lifecycle events (expire, revoke, delete)
How to integrate with PhoneKeyManager inside SwiftUI

This README explains both.

📒 Table of Contents

#-overview
#-phonekeycore-features
#-installation
#-key-architecture
#-key-generation
#-phonekeyinfo-api
#-acl-models
#️-signing--canonicalization
#-acl-chunk-builder-firmware-ready
#-local-acl-storage
#-phonekeysample-app-overview
#-sample-app-screens
#-crypto-provider-sodium
#-faq


🧭 Overview
PhoneKeyCore provides everything needed for mobile‑generated authentication keys in secure lock systems:

Automatic private key creation
Deterministic public key derivation
Command signing
ACL validation & chunking
Backend contract models

Designed to be dropped into any iOS app.

🔐 PhoneKeyCore Features

🔑 Key Generation — Supports:




















AlgorithmPrivate Key StorageNotesECDSA P‑256 (default)Secure, persistent SecKeyBest for modern iOS (13+)Ed2551932‑byte seed in KeychainSodium fallback for iOS 12
Both produce deterministic UUID‑style keyId
(SHA‑256 → 16 bytes → UUID).

🧾 ACL Handling
PhoneKeyCore includes:

PhoneKeyAcl
PhoneKeyAclEnvelope (lock‑compatible)
PhoneKeyAclRequest

With flexible decoding for:

int/string IDs
ISO‑8601 or epoch timestamps
Permissions array or keyed booleans


✍️ Signing

Ed25519 → 64‑byte signature
P‑256 → raw 64‑byte (r||s) signature
Converts DER → raw R/S safely


📦 ACL Chunk Builder
Produces 128‑byte hex‑encoded packets for BLE.
Final chunk format:
"xx" + <4 hex digits ACL length> + <remaining bytes>


💾 Keychain ACL Store
Store, list, update, delete ACLs locally.
Self‑healing index.

📦 Installation
Drag the PhoneKeyCore folder into your project.
If you need iOS 12 Ed25519 support:
Rubypod 'Sodium'pod 'Clibsodium'Show more lines
Then provide a CryptoProvider (example included in Sample App).

🧱 Key Architecture
PhoneKeyCore/
├── PhoneKeyManager.swift          # Key generation, signing, ACL chunking
├── PhoneKeyAcl.swift              # ACL model
├── PhoneKeyAclRequest.swift
├── PhoneKeyInfoRequest.swift
├── PhoneKeyInfoResponse.swift
├── PhoneKeySignedCommand.swift
├── Canonicalization utils         # ISO-8601, JSON sorting
└── Keychain helpers

The Sample App builds on this.

🔑 Key Generation
PhoneKeyManager is the entry point.
Swiftlet manager = PhoneKeyManager(    serviceName: "com.example.app.keys",    accessGroup: nil,    provider: SodiumCryptoProvider(),   // iOS 12 Ed25519    preferredAlgorithm: .ecdsaP256      // default)Show more lines
Ensure a key exists
Swiftlet info = try manager.ensureKeys()print(info.keyId)print(info.publicKeyRaw.base64EncodedString())Show more lines
Destroy
Swifttry manager.destroyKeys()Show more lines

🪪 PhoneKeyInfo API
Represents the active keypair:
Swiftpublic struct PhoneKeyInfo: Codable {    public let keyId: String    public let algorithm: SignatureAlgorithm    public let publicKeyRaw: Data    public let seed: Data          // Ed25519 only    public var status: PhoneKeyStatus    public let keyTag: Data?       // P-256 only}Show more lines

📬 ACL Models
PhoneKeyCore includes full request/response structures.
Request
Swiftlet req = PhoneKeyAclRequest(    userId: "123",    lockMac: "AA:BB:CC:DD:EE:FF",    phoneKeyId: "456")Show more lines
Response
Swiftlet env = try JSONDecoder().decode(PhoneKeyAclEnvelope.self, from: data)let acl = env.aclprint(acl.permissions.unlock)Show more lines
The envelope automatically inserts the signature into acl.signature.

✍️ Signing & Canonicalization
Sample App uses:
Swiftfunc signCommand(with manager: PhoneKeyManager,                 base: PhoneKeySignedCommand) throws -> PhoneKeySignedCommandfunc canonicalCommandBytes(for command: PhoneKeySignedCommand) throws -> DataShow more lines
Canonicalization enforces:

ISO‑8601 UTC w/ fractional seconds
Stable sorted key ordering
Signature field removed before signing

ACL canonicalization
Swiftfunc canonicalize(acl: PhoneKeyAcl) throws -> DataShow more lines

📦 ACL Chunk Builder (Firmware‑Ready)
Swiftlet chunks = try manager.buildACLChunks(acl: aclData)``Show more lines
Example output:
Plain Text[  "00<128 bytes hex>",  "01<128 bytes hex>",  "xx02d0<remaining>"]Show more lines

"xx" = last chunk
02d0 = acl.count (not including signature)


💾 Local ACL Storage
Swifttry manager.saveACL(acl)let stored = try manager.getACL(trackingId: "1")let list = try manager.listACLs()try manager.deleteACL(trackingId: "1")Show more lines
Self‑healing for corrupt entries.

📱 PhoneKeySample App Overview
Demonstrates real-world usage:

Ensuring keys
Validating existing keys
Showing Key ID & Public Key
Signing unlock commands
Soft-expiring / revoking keys
Clearing Keychain for test
Copy-to-clipboard
SwiftUI UI render of everything


🖥️ Sample App Screens
✔ Validate Current Key
Shows whether a key already exists.
🔑 Generate / Load Key
Runs ensureKeys().
📤 Register Key With Backend (Stub)
JSON{  "userId": "...",  "phoneUdid": "...",  "publicKey": "..."}Show more lines
📝 Build & Sign Unlock Command

Deterministic timestamp
Random nonce
Custom payload
Canonical JSON
Ed25519 or P‑256 signature
Base64 output for backend

📚 Logs
Scrollable output.
🔥 Key Lifecycle

Soft expire
Soft revoke
Delete (P‑256 + Ed25519)


🔧 Crypto Provider (Sodium)
Sample App includes:
SwiftgenerateEd25519Seed()derivePublicKey(fromSeed:)sign(message:withSeed:)getHash(of:)``Show more lines
Uses CommonCrypto for SHA‑256 to match CryptoKit.

❓ FAQ
Do I need Sodium?
Only for Ed25519 on iOS 12.
Should I prefer P‑256?
Yes — secure, hardware-backed, not exportable.
Does the lock expect raw P‑256 signatures?
Yes — 64‑byte (r||s).
Does canonicalization matter?
Yes — signature verification will fail otherwise.
