//
//  ContentView.swift
//  PhoneKeySample
//
//  Created by Joffrey Mann on 1/7/26.
//

import SwiftUI

struct PhoneKeySampleScreen: View {
    // Your existing VM (plain class)
    private let vm = PhoneKeySampleViewModel()
    
    // Local @State mirrors so SwiftUI re-renders
    @State private var keyId: String = ""
    @State private var publicKeyBase64: String = ""
    @State private var status: String = ""
    @State private var signedCommandJSON: String = ""
    @State private var logs: [String] = []
    @State private var overlockOverride: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current Key Status") {
                    Button {
                        let exists = vm.validateCurrentKey()
                        keyId = vm.keyId
                        publicKeyBase64 = vm.publicKeyBase64
                        status = vm.status
                        logs = vm.logs
                    } label: {
                        Label("Check Current Key", systemImage: "magnifyingglass")
                    }
                    
                    if status == "Ready" {
                        Text("✅ Current Key Available")
                            .foregroundStyle(.green)
                        Text("Key ID: \(vm.keyId)").font(.caption)
                        Text("Public Key: \(publicKeyBase64.prefix(32))…").font(.caption)
                    } else if status == "No Key" {
                        Text("⚠️ No Key Found").foregroundStyle(.orange)
                    } else if status == "Error" {
                        Text("❌ Error validating key").foregroundStyle(.red)
                    }
                }
                // Phone Key
                Section("Phone Key") {
                    HStack {
                        Button {
                            vm.ensurePhoneKey()
                            // mirror values into @State so UI updates
                            keyId = vm.keyId
                            publicKeyBase64 = vm.publicKeyBase64
                            status = vm.status
                            logs = vm.logs
                        } label: {
                            Label("Ensure Key", systemImage: "key.fill")
                        }
                        Spacer()
                        Text(status.isEmpty ? "—" : status)
                            .foregroundStyle(status == "Ready" ? .green : .secondary)
                    }
                    
                    if !keyId.isEmpty {
                        HStack {
                            Text("Key ID")
                            Spacer()
                            Text(keyId)
                                .font(.caption)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Public Key (Base64)").font(.footnote)
                            ScrollView(.horizontal) {
                                Text(publicKeyBase64)
                                    .font(.caption)
                                    .textSelection(.enabled)
                            }
                        }
                        
                        HStack {
                            Button {
                                vm.copyPublicKey()
                                logs = vm.logs
                            } label: {
                                Label("Copy Public Key", systemImage: "doc.on.doc")
                            }
                            Spacer()
                            Button {
                                vm.registerPublicKeyWithBackend()
                                logs = vm.logs
                            } label: {
                                Label("Register (stub)", systemImage: "arrow.up.circle")
                            }
                        }
                    } else {
                        Text("Tap **Ensure Key** to create/load the phone key.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Command signing
                Section("Build & Sign Unlock Command") {
                    Toggle("Overlock override", isOn: bindingForOverride)
                    
                    Button {
                        // push the current UI state into the VM before signing
                        vm.overlockOverride = overlockOverride
                        vm.buildAndSignUnlockCommand()
                        // mirror result back into UI
                        signedCommandJSON = vm.signedCommandJSON
                        logs = vm.logs
                    } label: {
                        Label("Sign Unlock Command", systemImage: "signature")
                    }
                    
                    if !signedCommandJSON.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Signed Command (JSON)").font(.footnote)
                            ScrollView {
                                Text(signedCommandJSON)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 140)
                        }
                        Button {
                            vm.copySignedCommand()
                            logs = vm.logs
                        } label: {
                            Label("Copy Signed Command", systemImage: "doc.on.doc")
                        }
                    } else {
                        Text("No command signed yet.").foregroundStyle(.secondary)
                    }
                }
                
                // Logs
                Section("Logs") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(logs.indices, id: \.self) { i in
                                Text(logs[i])
                                    .font(.caption)
                                    .monospaced()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 160)
                }
            }
            .navigationTitle("Phone Key POC")
        }
    }
    
    /// Correct computed Binding: single property, no duplicate 'private var' declaration.
    private var bindingForOverride: Binding<Bool> {
        Binding(
            get: { overlockOverride },              // read from local @State
            set: { newValue in                      // write to local @State and the VM
                overlockOverride = newValue
                vm.overlockOverride = newValue
            }
        )
    }
}

#Preview {
    PhoneKeySampleScreen()
}
