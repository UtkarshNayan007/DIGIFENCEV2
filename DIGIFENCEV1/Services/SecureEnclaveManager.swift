//
//  SecureEnclaveManager.swift
//  DIGIFENCEV1
//
//  Manages EC P-256 keypair in the Secure Enclave with biometric binding.
//  Key generation, public key export, and biometric-guarded signing.
//

import Foundation
import Security
import LocalAuthentication

final class SecureEnclaveManager {
    
    static let shared = SecureEnclaveManager()
    
    private let keyTag = "com.digifence.secureenclave.signing".data(using: .utf8)!
    private let keyLabel = "DigiFence Signing Key"
    
    /// Whether the device has a Secure Enclave
    var isSecureEnclaveAvailable: Bool {
        if #available(iOS 16.0, *) {
            return SecureEnclave.isAvailable
        }
        // Fallback check: try to query for SE token
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
        ]
        var error: Unmanaged<CFError>?
        guard let _ = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            // If we get an error about SE not being available, return false
            return false
        }
        return true
    }
    
    // MARK: - Key Generation
    
    /// Generate an EC P-256 keypair in the Secure Enclave with biometric access control.
    /// Returns the base64-encoded public key (X9.62 uncompressed format).
    func generateKeyPair() throws -> String {
        // Delete any existing key first
        deleteKeyPair()
        
        // Create access control: require biometric (Face ID / Touch ID)
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .userPresence],
            nil
        ) else {
            throw SecureEnclaveError.accessControlCreationFailed
        }
        
        // Key attributes
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrLabel as String: keyLabel,
                kSecAttrAccessControl as String: accessControl,
            ] as [String: Any],
        ]
        
        // Use Secure Enclave if available, otherwise software fallback
        if isSecureEnclaveAvailable {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let err = error?.takeRetainedValue() as? Error
            throw SecureEnclaveError.keyGenerationFailed(err?.localizedDescription ?? "Unknown error")
        }
        
        // Extract public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.publicKeyExtractionFailed
        }
        
        return try exportPublicKeyBase64(publicKey)
    }
    
    // MARK: - Public Key Export
    
    /// Export the public key as base64-encoded X9.62 uncompressed representation.
    /// This is the format expected by the server (04 || x || y, 65 bytes).
    func exportPublicKeyBase64(_ publicKey: SecKey? = nil) throws -> String {
        let key: SecKey
        if let providedKey = publicKey {
            key = providedKey
        } else {
            key = try getPublicKey()
        }
        
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            let err = error?.takeRetainedValue() as? Error
            throw SecureEnclaveError.publicKeyExportFailed(err?.localizedDescription ?? "Unknown error")
        }
        
        return publicKeyData.base64EncodedString()
    }
    
    // MARK: - Signing
    
    /// Sign data using the Secure Enclave private key with biometric authentication.
    /// Uses ECDSA with SHA-256 (ecdsaSignatureMessageX962SHA256).
    /// This will trigger Face ID / Touch ID prompt.
    func sign(data: Data) throws -> String {
        let privateKey = try getPrivateKey()
        
        let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256
        
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw SecureEnclaveError.algorithmNotSupported
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            data as CFData,
            &error
        ) as Data? else {
            let err = error?.takeRetainedValue() as? Error
            throw SecureEnclaveError.signingFailed(err?.localizedDescription ?? "Unknown error")
        }
        
        return signature.base64EncodedString()
    }
    
    /// Sign a base64-encoded nonce string. Convenience method for the activation flow.
    func signNonce(_ nonceBase64: String) throws -> String {
        guard let nonceData = Data(base64Encoded: nonceBase64) else {
            throw SecureEnclaveError.invalidNonceData
        }
        return try sign(data: nonceData)
    }
    
    // MARK: - Key Retrieval
    
    private func getPrivateKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let key = item else {
            throw SecureEnclaveError.keyNotFound
        }
        
        return key as! SecKey
    }
    
    func getPublicKey() throws -> SecKey {
        let privateKey = try getPrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.publicKeyExtractionFailed
        }
        return publicKey
    }
    
    /// Check if a signing key already exists.
    func hasExistingKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Key Deletion
    
    func deleteKeyPair() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum SecureEnclaveError: LocalizedError {
    case accessControlCreationFailed
    case keyGenerationFailed(String)
    case publicKeyExtractionFailed
    case publicKeyExportFailed(String)
    case algorithmNotSupported
    case signingFailed(String)
    case keyNotFound
    case invalidNonceData
    case secureEnclaveNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .accessControlCreationFailed:
            return "Failed to create biometric access control."
        case .keyGenerationFailed(let msg):
            return "Key generation failed: \(msg)"
        case .publicKeyExtractionFailed:
            return "Failed to extract public key."
        case .publicKeyExportFailed(let msg):
            return "Failed to export public key: \(msg)"
        case .algorithmNotSupported:
            return "Signing algorithm not supported on this device."
        case .signingFailed(let msg):
            return "Signing failed: \(msg). Please try biometric authentication again."
        case .keyNotFound:
            return "No signing key found. Please complete onboarding."
        case .invalidNonceData:
            return "Invalid nonce data received from server."
        case .secureEnclaveNotAvailable:
            return "Secure Enclave is not available. Manual verification required."
        }
    }
}

// MARK: - SecureEnclave Availability Check (iOS 16+)

@available(iOS 16.0, *)
private enum SecureEnclave {
    static var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return canEvaluate
    }
}
