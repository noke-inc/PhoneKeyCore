
# SmartEntryCore POCs – Phone Key & NFC Tag Demo

This repo contains two small, focused proofs of concept you can run on-device:

- **Phone Key Generation & Command Signing (Ed25519)** — iOS 12+ (Sodium fallback) / iOS 13+ (CryptoKit)
- **NFC Tag Read/Write (NDEF)** — Read on iOS 11+, Write on iOS 13+

Both are designed to be integrated into **SmartEntryCore** with clean boundaries and extension‑safe builds.

---

## Table of Contents
- [Overview](#overview)
- [Project Structure](#project-structure)
- [Phone Key POC](#phone-key-poc)
  - [Model: `PhoneKeySignedCommand`](#model-phonekeysignedcommand)
  - [Canonicalization & Signing](#canonicalization--signing)
  - [SwiftUI Demo Screen](#swiftui-demo-screen)
  - [Troubleshooting (Sodium/Clibsodium)](#troubleshooting-sodiumclibsodium)
- [NFC POC](#nfc-poc)
  - [Minimal Tag Model: `NokeTagInfo`](#minimal-tag-model-noketaginfo)
  - [Read (iOS 11+) & Write (iOS 13+)](#read-ios-11--write-ios-13)
  - [SmartEntryCore Integration Notes](#smartentrycore-integration-notes)
- [Build & Run](#build--run)
- [FAQ](#faq)
- [License](#license)

---

## Overview

**Phone Key POC**
- Generates/loads a **phone key** (Ed25519 private seed in Keychain, public key derivation).
- Builds a minimal unlock command, **canonicalizes** (stable ISO‑8601 w/ fractional secs + lexicographic key order), and **signs** with the phone key.
- Displays the **Key ID**, **Public Key (Base64)**, and **Signed Command JSON**, with copy actions.

**NFC POC**
- Reads an NFC tag carrying a small JSON payload (NDEF). *(iOS 11+ real device)*
- Writes a minimal JSON payload to compatible tags via NDEF. *(iOS 13+ real device)*
- Uses availability guards and target membership rules to stay extension‑safe.

> **Note**: Core NFC is available only on real devices and is **not available in app extensions**.

---

## Project Structure

```
PhoneKeySample/
├─ Models/
│  ├─ PhoneKeySignedCommand.swift        # Command model + canonicalization helper
├─ Use Cases/
│  ├─ PhoneKeySampleViewModel.swift      # View model that ensures key, signs command
├─ Views/
│  ├─ PhoneKeySampleScreen.swift         # SwiftUI UI for key + signing
├─ NFC/
│  ├─ NFCReaderWriter.swift              # Read (iOS 11+) + write wrapper with guards
│  ├─ NFCWriter13.swift                  # iOS 13+ tag writing via NFCTagReaderSession
│  └─ NfcPayload.swift                   # Encode/decode NDEF payloads
├─ Podfile                                # CocoaPods – Sodium/Clibsodium etc.
└─ README.md
```

---

## Phone Key POC

### Model: `PhoneKeySignedCommand`
A compact schema for phone‑signed commands (string timestamps to ensure deterministic canonicalization):

```swift
struct PhoneKeySignedCommand: Codable {
    struct Signature: Codable {
        let algorithm: String       // "Ed25519"
        let value: String           // Base64
    }
    let commandId: String
    let type: String
    let createdAt: String          // ISO-8601 UTC with fractional seconds
    let nonce: String              // Base64 16–32 bytes
    let payload: [String:String]
    var signature: Signature
}
```

### Canonicalization & Signing

- **Canonicalization**: `canonicalCommandBytes(for:)` → encodes `PhoneKeySignedCommand` into deterministic bytes (ISO‑8601 UTC w/ fractional seconds + lexicographic key order).
- **Signing**: `signCommand(with:base:)` → signs canonical bytes with the phone key and returns a fully signed command.

```swift
func signCommand(with manager: PhoneKeyManager, base: PhoneKeySignedCommand) throws -> PhoneKeySignedCommand {
    let bytes = try canonicalCommandBytes(for: base)
    let signature = try manager.sign(bytes)
    var signed = base
    signed.signature = .init(algorithm: SignatureAlgorithm.ed25519.rawValue,
                             value: signature.base64EncodedString())
    return signed
}
```

### SwiftUI Demo Screen
The `PhoneKeySampleScreen` view calls your view model methods to:
- **Ensure Key** → shows Key ID & Public Key
- **Sign Unlock Command** → shows Signed Command JSON
- **Copy** actions for quick testing

> If your `PhoneKeySampleViewModel` is not an `ObservableObject`, mirror values into local `@State` after actions (see sample view). If you make the VM `ObservableObject` with `@Published` properties, the UI will auto‑update without glue code.

### Troubleshooting (Sodium/Clibsodium)
- If you see **Unable to find module dependency: 'Sodium'** or **'Clibsodium'**:
  - Add both pods to the target that imports them:
    ```ruby
    use_frameworks! :linkage => :static
    target 'PhoneKeySample' do
      pod 'Sodium'
      pod 'Clibsodium'
    end
    ```
  - Run `pod install`, open the **.xcworkspace**, clean DerivedData, rebuild.
  - Ensure files with `import Sodium` belong to the **PhoneKeySample** target (File Inspector → Target Membership).
  - Avoid mixing SPM and Pods for Sodium.

---

## NFC POC

### Minimal Tag Model: `NokeTagInfo`
Keep NFC payload tiny and versioned for testing:

```swift
public struct NokeTagInfo: Codable, Equatable {
    public let v: Int     // schema version (start at 1)
    public let label: String   // short label or app route
    public init(v: Int = 1, label: String) { self.v = v; self.label = label }
}
```

Helpers for NDEF external type (e.g., `noke.tag/info`):

```swift
enum NfcPayload {
    static let externalType = "noke.tag/info"
    #if canImport(CoreNFC)
    static func makePayload(from info: NokeTagInfo) throws -> NFCNDEFPayload { /* ... */ }
    static func parse(_ record: NFCNDEFPayload) throws -> NokeTagInfo { /* ... */ }
    #endif
}
```

### Read (iOS 11+) & Write (iOS 13+)
- **Read**: `NFCNDEFReaderSession` (iOS 11+) on a **real device**; parse first record as `NokeTagInfo`.
- **Write**: `NFCTagReaderSession` (iOS 13+); connect to `NFCNDEFTag` and call `writeNDEF(...)` with a minimal payload.
- Valid polling options for writing: `.iso14443`, `.iso15693`, `.iso18092`.

> Core NFC isn’t available on the simulator and not allowed in app extensions. Keep NFC files out of extension targets or wrap with `#if !APP_EXTENSION` and annotate classes with `@available(iOSApplicationExtension, unavailable)`.

### SmartEntryCore Integration Notes
- Link **CoreNFC** weakly in the framework target:
  - **Build Settings → Other Linker Flags**: `-weak_framework CoreNFC`
- Keep iOS 13+ writer in `NFCWriter13.swift` annotated `@available(iOS 13.0, *)`.
- Exclude NFC sources from extension target membership (File Inspector) or via compile flag `APP_EXTENSION`.
- App target must add capability **Near Field Communication Tag Reading** and `NFCReaderUsageDescription` in Info.plist.

---

## Build & Run

1. **CocoaPods**
   ```bash
   pod repo update
   pod install
   ```
   Open `PhoneKeySample.xcworkspace` (not the project).

2. **Device**
   - Phone Key POC: runs on simulator or device.
   - NFC POC: requires a **real iPhone** (NFC hardware). Writing requires **iOS 13+**.

3. **SwiftUI Screens**
   - Set `PhoneKeySampleScreen()` as your app’s root view for the Phone Key demo.
   - For NFC, present the read/write screen from your app; ensure Info.plist and capability are set on the app target.

---

## FAQ

**Why does the UI not update after actions?**  
If your view model isn’t `ObservableObject` with `@Published` properties, SwiftUI won’t auto‑refresh. Either mirror values into local `@State` after each action or adopt `ObservableObject/@Published`.

**I get '.iso7816' polling errors.**  
Use only `.iso14443`, `.iso15693`, `.iso18092` in `NFCTagReaderSession`. ISO7816 tags are still surfaced via `.iso14443` and delivered as `NFCTag.iso7816` in callbacks.

**Core NFC not found on simulator.**  
Core NFC is device‑only. Build succeeds with stubs, but actions return “not available” on the simulator.

---

## License

MIT License. Copyright © 2026 Noke Inc.
