//
//  SecureEnclaveTests.swift
//  DIGIFENCEV1Tests
//
//  Tests for key generation, public key export, and signing.
//  Uses software keys since Secure Enclave is not available in simulator.
//

#if canImport(XCTest)
import XCTest
import Security
@testable import DIGIFENCEV1

final class SecureEnclaveTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        SecureEnclaveManager.shared.deleteKeyPair()
    }
    
    // MARK: - Key Generation
    
    func testKeyGeneration() throws {
        let publicKeyBase64 = try SecureEnclaveManager.shared.generateKeyPair()
        
        XCTAssertFalse(publicKeyBase64.isEmpty, "Public key should not be empty")
        
        // Verify it's valid base64
        let data = Data(base64Encoded: publicKeyBase64)
        XCTAssertNotNil(data, "Public key should be valid base64")
        
        // EC P-256 uncompressed public key is 65 bytes (04 || x || y)
        XCTAssertEqual(data?.count, 65, "EC P-256 uncompressed public key should be 65 bytes")
        
        // First byte should be 0x04 (uncompressed point indicator)
        XCTAssertEqual(data?.first, 0x04, "First byte should be 0x04 for uncompressed EC point")
    }
    
    func testKeyExists() throws {
        XCTAssertFalse(SecureEnclaveManager.shared.hasExistingKey(), "No key should exist initially")
        
        _ = try SecureEnclaveManager.shared.generateKeyPair()
        XCTAssertTrue(SecureEnclaveManager.shared.hasExistingKey(), "Key should exist after generation")
    }
    
    func testKeyDeletion() throws {
        _ = try SecureEnclaveManager.shared.generateKeyPair()
        XCTAssertTrue(SecureEnclaveManager.shared.hasExistingKey())
        
        SecureEnclaveManager.shared.deleteKeyPair()
        XCTAssertFalse(SecureEnclaveManager.shared.hasExistingKey(), "Key should not exist after deletion")
    }
    
    // MARK: - Public Key Export
    
    func testPublicKeyExportConsistency() throws {
        _ = try SecureEnclaveManager.shared.generateKeyPair()
        
        let key1 = try SecureEnclaveManager.shared.exportPublicKeyBase64()
        let key2 = try SecureEnclaveManager.shared.exportPublicKeyBase64()
        
        XCTAssertEqual(key1, key2, "Same key should export to same base64 consistently")
    }
    
    func testDifferentKeysAreDifferent() throws {
        let key1 = try SecureEnclaveManager.shared.generateKeyPair()
        SecureEnclaveManager.shared.deleteKeyPair()
        let key2 = try SecureEnclaveManager.shared.generateKeyPair()
        
        XCTAssertNotEqual(key1, key2, "Different key generations should produce different public keys")
    }
    
    // MARK: - Signing
    
    func testSignData() throws {
        _ = try SecureEnclaveManager.shared.generateKeyPair()
        
        let testData = "Hello, DigiFence!".data(using: .utf8)!
        
        // Note: In simulator, this may work without biometric prompt
        // On device, it would trigger Face ID / Touch ID
        let signature = try SecureEnclaveManager.shared.sign(data: testData)
        
        XCTAssertFalse(signature.isEmpty, "Signature should not be empty")
        
        // Verify it's valid base64
        let sigData = Data(base64Encoded: signature)
        XCTAssertNotNil(sigData, "Signature should be valid base64")
        
        // ECDSA signatures are DER-encoded, typically 70-72 bytes for P-256
        XCTAssertGreaterThan(sigData?.count ?? 0, 60, "ECDSA P-256 signature should be at least 60 bytes")
        XCTAssertLessThan(sigData?.count ?? 200, 80, "ECDSA P-256 signature should be less than 80 bytes")
    }
    
    func testSignNonce() throws {
        _ = try SecureEnclaveManager.shared.generateKeyPair()
        
        // Generate a random nonce like the server would
        var nonceBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, nonceBytes.count, &nonceBytes)
        let nonceBase64 = Data(nonceBytes).base64EncodedString()
        
        let signature = try SecureEnclaveManager.shared.signNonce(nonceBase64)
        XCTAssertFalse(signature.isEmpty)
    }
    
    func testSignatureVerifiesLocally() throws {
        // Generate key
        let publicKeyBase64 = try SecureEnclaveManager.shared.generateKeyPair()
        let publicKeyData = Data(base64Encoded: publicKeyBase64)!
        
        // Sign data
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let signatureBase64 = try SecureEnclaveManager.shared.sign(data: testData)
        let signatureData = Data(base64Encoded: signatureBase64)!
        
        // Reconstruct public key from raw bytes
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256,
        ]
        
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyData as CFData, attributes as CFDictionary, &error) else {
            XCTFail("Failed to create public key from raw data: \(error?.takeRetainedValue().localizedDescription ?? "")")
            return
        }
        
        // Verify
        let isValid = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            testData as CFData,
            signatureData as CFData,
            &error
        )
        
        XCTAssertTrue(isValid, "Signature should verify with the correct public key")
    }
}

#endif
