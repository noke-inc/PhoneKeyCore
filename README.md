📱🔐 PhoneKeyCore + Sample App
Unified Phone‑Key Generation, ACL Handling, Command Signing & Demo UI
This repository contains:


PhoneKeyCore — a standalone framework that handles:

Phone‑key generation & storage
Ed25519 and ECDSA P‑256 signing
ACL decoding, canonicalization, signing & chunking
JSON utilities, ISO‑8601 helpers
Lock‑compatible ACL storage in Keychain



PhoneKeySample App — an end‑to‑end demonstration showing:

How to ensure/load a phone key
How to send your public key to your backend
How to build, canonicalize & sign unlock commands
How to test key lifecycle events (expire, revoke, delete)
How to integrate with PhoneKeyManager in UI code



This README explains both.

Table of Contents

#overview
#phonekeycore-features
#installation
#key-architecture
#key-generation
#phonekeyinfo-api
#acl-models
#signing--canonicalization
#acl-chunk-builder
#local-acl-storage
#sample-app-overview
#sample-app-screens
#crypto-provider
#faq


🧭 Overview
PhoneKeyCore provides everything needed for mobile‑generated authentication keys in secure lock systems:

Automatic private key creation
Deterministic public key derivation
Command signing
ACL validation and chunking
Backend contract models

It is designed to be dropped into any iOS app.

🔐 PhoneKeyCore Features
🔑 Key Generation
Supports:




















AlgorithmPrivate Key StorageNotesECDSA P‑256 (default)Secure, persistent SecKeyOptimal for 13+ / modern devicesEd2551932‑byte seed stored in KeychainUses Sodium for iOS 12 fallback
Both produce deterministic UUID‑style keyId (SHA‑256 → 16 bytes → UUID).

🧾 ACL Handling
PhoneKeyCore includes:

PhoneKeyAcl
PhoneKeyAclEnvelope (lock-compatible)
PhoneKeyAclRequest
Flexible decoding for:

int/string IDs
ISO‑8601 or epoch seconds
Permissions array or keyed booleans




✍️ Signing

Ed25519 → 64-byte
P‑256 → raw (r||s) 64-byte
Converts DER signatures safely


📦 ACL Chunk Builder
Produces 128‑byte hex‑encoded packets ready for BLE transfer.
Final chunk format:
"xx" + <4 hex digits ACL length> + <remaining bytes>


💾 Keychain ACL Store
Store, list, update, delete ACLs locally.

📦 Installation
Drag PhoneKeyCore into your project.
If you need iOS 12 Ed25519 support, you must include:
Rubypod 'Sodium'pod 'Clibsodium'Show more lines
Then provide a CryptoProvider (see the Sample App’s provider).

🧱 Key Architecture
PhoneKeyCore/
├── PhoneKeyManager.swift         # Key generation, signing, ACL chunking
├── PhoneKeyAcl.swift             # ACL model
├── PhoneKeyAclRequest.swift
├── PhoneKeyInfoRequest.swift
├── PhoneKeyInfoResponse.swift
├── PhoneKeySignedCommand.swift
├── Canonicalization utils        # ISO-8601, JSON sorting
└── Keychain helpers

The Sample App builds on this.

🔑 Key Generation
PhoneKeyManager is the entry point.
Swiftlet manager = PhoneKeyManager(    serviceName: "com.example.app.keys",    accessGroup: nil,    provider: SodiumCryptoProvider(),   // required for iOS 12 Ed25519    preferredAlgorithm: .ecdsaP256      // default)Show more lines
Ensure a key exists
Swiftlet info = try manager.ensureKeys()print(info.keyId)print(info.publicKeyRaw.base64EncodedString())Show more lines
Destroy
Swifttry manager.destroyKeys()Show more lines

🪪 PhoneKeyInfo API
Represents the active keypair:
Swiftpublic struct PhoneKeyInfo: Codable {    public let keyId: String    public let algorithm: SignatureAlgorithm    public let publicKeyRaw: Data    public let seed: Data        // Ed25519 only    public var status: PhoneKeyStatus    public let keyTag: Data?     // P-256 only}Show more lines

📬 ACL Models
PhoneKeyCore includes full request/response structures.
Request
Swiftlet req = PhoneKeyAclRequest(    userId: "123",    lockMac: "AA:BB:CC:DD:EE:FF",    phoneKeyId: "456")Show more lines
Response
Swiftlet env = try JSONDecoder().decode(PhoneKeyAclEnvelope.self, from: data)let acl = env.aclprint(acl.permissions.unlock)Show more lines
The PhoneKeyAclEnvelope automatically inserts the top‑level signature back into acl.signature.

✍️ Signing & Canonicalization
The Sample App uses:
Swiftfunc signCommand(with manager: PhoneKeyManager, base: PhoneKeySignedCommand) throws -> PhoneKeySignedCommandfunc canonicalCommandBytes(for command: PhoneKeySignedCommand) throws -> DataShow more lines
Canonicalization enforces:

ISO‑8601 UTC with fractional seconds
Stable sorted key order
No signature field included in canonical bytes

ACLs use similar logic:
Swiftfunc canonicalize(acl: PhoneKeyAcl) throws -> Data``Show more lines

📦 ACL Chunk Builder (Firmware‑Ready)
Swiftlet chunks = try manager.buildACLChunks(acl: aclData)``Show more lines
Output:
[
  "00 <128 bytes hex>",
  "01 <128 bytes hex>",
  "xx 02d0 <final bytes>"
]

Where:

"xx" marks last chunk
02d0 is ACL length (acl.count, not including signature)


💾 Local ACL Storage
Swifttry manager.saveACL(acl)let stored = try manager.getACL(trackingId: "1")let list = try manager.listACLs()try manager.deleteACL(trackingId: "1")``Show more lines
Self‑healing: corrupted entries drop from index.

📱 PhoneKeySample App Overview
Demonstrates real-world usage of PhoneKeyCore:

Ensuring keys
Validating existing keys
Showing Key ID & Public Key
Signing unlock commands
Soft-expiring / revoking keys
Clearing Keychain for testing
Copy-to-clipboard actions
Full SwiftUI UI


🖥️ Sample App Screens
✔ Validate Current Key
Shows whether a key already exists.
🔑 Generate / Load Key
Runs ensureKeys().
📤 Register Key With Backend (Stub)
You would POST:
JSON{  "userId": "...",  "phoneUdid": "...",  "publicKey": "..."}Show more lines
📝 Build & Sign Unlock Command

Deterministic timestamp
Random nonce
Custom payload
Canonical JSON
Ed25519 or P‑256 signature
JSON output ready for backend

📚 Logs
Scrollable debugging output.
🔥 Key Lifecycle

Soft expire
Soft revoke
Delete (seed + P‑256)


🔧 Crypto Provider (Sodium)
The Sample App includes SodiumCryptoProvider, which implements:
SwiftgenerateEd25519Seed()derivePublicKey(fromSeed:)sign(message:withSeed:)getHash(of:)Show more lines
and uses CommonCrypto for SHA‑256, ensuring compatibility with CryptoKit.

❓ FAQ
Do I need Sodium?
Only if you want Ed25519 on iOS 12.
Should I prefer P‑256?
Yes. It's secure, hardware-backed, non-exportable, and default.
Does the lock expect raw P‑256 signatures?
Yes — 64‑byte (r||s).
Does canonicalization matter?
Yes, commands & ACLs must be canonical or signatures won't verify.
