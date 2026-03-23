//
//  QRScannerViewModel.swift
//  DIGIFENCEV1
//
//  Handles QR code scanning and pass verification with Firebase.
//

import Foundation
import Combine
@preconcurrency import AVFoundation
import FirebaseAuth
import FirebaseFirestore

struct ScanResult {
    let isValid: Bool
    let message: String
    let eventTitle: String?
    let entryCode: String?
    let userName: String?
}

@MainActor
final class QRScannerViewModel: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var scanResult: ScanResult?
    @Published var errorMessage: String?
    
    private let _captureSession = AVCaptureSession()
    var captureSession: AVCaptureSession { _captureSession }
    
    private var metadataOutput: AVCaptureMetadataOutput?
    private let firebase = FirebaseManager.shared
    private var isProcessing = false
    
    override init() {
        super.init()
        setupCamera()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if _captureSession.canAddInput(input) {
            _captureSession.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if _captureSession.canAddOutput(output) {
            _captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            metadataOutput = output
        }
    }

    // MARK: - Scanning Control
    
    func startScanning() {
        let session = _captureSession
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        isScanning = true
    }
    
    func stopScanning() {
        let session = _captureSession
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
        isScanning = false
    }
    
    func resetScan() {
        scanResult = nil
        isProcessing = false
        startScanning()
    }
    
    // MARK: - Code Verification
    
    func verifyCode(_ code: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        stopScanning()
        
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            // Short codes (≤8 chars) are entry codes; longer strings are QR tokens
            let result: ScanResult
            if trimmedCode.count <= 8 {
                result = try await verifyEntryCode(trimmedCode.uppercased())
            } else {
                result = try await verifyPassToken(trimmedCode)
            }
            
            if result.isValid {
                HapticManager.shared.success()
            } else {
                HapticManager.shared.error()
            }
            scanResult = result
        } catch {
            HapticManager.shared.error()
            scanResult = ScanResult(
                isValid: false,
                message: error.localizedDescription,
                eventTitle: nil,
                entryCode: nil,
                userName: nil
            )
        }
        
        isProcessing = false
    }

    /// Verify a ticket by its short entry code (admin manual entry)
    private func verifyEntryCode(_ code: String) async throws -> ScanResult {
        let snapshot = try await firebase.ticketsCollection
            .whereField("entryCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else {
            return ScanResult(
                isValid: false,
                message: "No pass found with entry code \"\(code)\".",
                eventTitle: nil,
                entryCode: nil,
                userName: nil
            )
        }
        
        let ticket = try doc.data(as: Ticket.self)
        
        // Check if already used (scanned)
        if ticket.qrScanned == true {
            return ScanResult(
                isValid: false,
                message: "This pass has already been checked in.",
                eventTitle: nil,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // Check ticket status
        guard ticket.status == .active else {
            return ScanResult(
                isValid: false,
                message: "Pass is not active. Status: \(ticket.statusDisplayText)",
                eventTitle: nil,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // Fetch event details
        let eventDoc = try await firebase.eventsCollection.document(ticket.eventId).getDocument()
        let event = try? eventDoc.data(as: Event.self)
        
        // 1. Verify event exists
        guard let event = event else {
            return ScanResult(
                isValid: false,
                message: "Event not found for this ticket.",
                eventTitle: nil,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // 2. Verify event is active and not ended
        let now = Date()
        if !event.isActive {
            return ScanResult(
                isValid: false,
                message: "Event \"\(event.title)\" is currently inactive (disabled by admin).",
                eventTitle: event.title,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        if let endsAt = event.endsAt?.dateValue(), endsAt <= now {
            return ScanResult(
                isValid: false,
                message: "Event \"\(event.title)\" has already ended.",
                eventTitle: event.title,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // 3. Verify the scanner is authorized (organizer or assigned security)
        let currentUid = Auth.auth().currentUser?.uid
        let isAuthorized = await isAuthorizedForCheckIn(uid: currentUid, event: event)
        guard isAuthorized else {
            return ScanResult(
                isValid: false,
                message: "Access Denied: You are not authorized to check in for this event.",
                eventTitle: event.title,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // Fetch user details
        let userDoc = try await firebase.usersCollection.document(ticket.ownerId).getDocument()
        let user = try? userDoc.data(as: AppUser.self)
        
        // Mark as scanned with check-in time and scanner ID
        var updatePayload: [String: Any] = [
            "qrScanned": true,
            "scannedAt": FieldValue.serverTimestamp(),
            "checkInTime": FieldValue.serverTimestamp(),
            "insideFence": true
        ]
        if let currentUid = currentUid {
            updatePayload["scannedBy"] = currentUid
        }
        
        try await firebase.ticketsCollection.document(doc.documentID).updateData(updatePayload)
        
        return ScanResult(
            isValid: true,
            message: "Check-in successful!",
            eventTitle: event.title,
            entryCode: ticket.entryCode,
            userName: user?.displayName
        )
    }

    /// Verify a ticket by its QR token (scanner)
    private func verifyPassToken(_ token: String) async throws -> ScanResult {
        // Query tickets collection for matching qrToken
        let snapshot = try await firebase.ticketsCollection
            .whereField("qrToken", isEqualTo: token)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else {
            return ScanResult(
                isValid: false,
                message: "Pass not found. Invalid QR code.",
                eventTitle: nil,
                entryCode: nil,
                userName: nil
            )
        }
        
        let ticket = try doc.data(as: Ticket.self)
        
        // Check if already used (scanned)
        if ticket.qrScanned == true {
            return ScanResult(
                isValid: false,
                message: "This pass has already been used.",
                eventTitle: nil,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }

        // Check ticket status
        guard ticket.status == .active else {
            return ScanResult(
                isValid: false,
                message: "Pass is not active. Status: \(ticket.statusDisplayText)",
                eventTitle: nil,
                entryCode: nil,
                userName: nil
            )
        }
        
        // Fetch event details
        let eventDoc = try await firebase.eventsCollection.document(ticket.eventId).getDocument()
        let event = try? eventDoc.data(as: Event.self)
        
        // 1. Verify event exists
        guard let event = event else {
            return ScanResult(
                isValid: false,
                message: "Event not found for this ticket.",
                eventTitle: nil,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // 2. Verify event is active and not ended
        let now = Date()
        if !event.isActive {
            return ScanResult(
                isValid: false,
                message: "Event \"\(event.title)\" is inactive.",
                eventTitle: event.title,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        if let endsAt = event.endsAt?.dateValue(), endsAt <= now {
            return ScanResult(
                isValid: false,
                message: "Event \"\(event.title)\" has already ended.",
                eventTitle: event.title,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // 3. Verify the scanner is authorized (organizer or assigned security)
        let currentUid2 = Auth.auth().currentUser?.uid
        let isAuthorized2 = await isAuthorizedForCheckIn(uid: currentUid2, event: event)
        guard isAuthorized2 else {
            return ScanResult(
                isValid: false,
                message: "Access Denied: You are not authorized to check in for this event.",
                eventTitle: event.title,
                entryCode: ticket.entryCode,
                userName: nil
            )
        }
        
        // Fetch user details
        let userDoc = try await firebase.usersCollection.document(ticket.ownerId).getDocument()
        let user = try? userDoc.data(as: AppUser.self)
        
        // Mark as scanned with check-in time and scanner ID
        var updatePayload: [String: Any] = [
            "qrScanned": true,
            "scannedAt": FieldValue.serverTimestamp(),
            "checkInTime": FieldValue.serverTimestamp(),
            "insideFence": true
        ]
        if let currentUid = currentUid2 {
            updatePayload["scannedBy"] = currentUid
        }
        
        try await firebase.ticketsCollection.document(doc.documentID).updateData(updatePayload)
        
        return ScanResult(
            isValid: true,
            message: "Check-in successful!",
            eventTitle: event.title,
            entryCode: ticket.entryCode,
            userName: user?.displayName
        )
    }

    // MARK: - Authorization Helper

    /// Check if current user is allowed to perform check-in for this event.
    /// Allowed: event organizer (admin) OR security personnel assigned to this event.
    private func isAuthorizedForCheckIn(uid: String?, event: Event) async -> Bool {
        guard let uid = uid else { return false }

        // Admin organizer
        if event.organizerId == uid { return true }

        // Security assigned to this event
        do {
            let userDoc = try await firebase.usersCollection.document(uid).getDocument()
            guard let data = userDoc.data() else { return false }
            let role = data["role"] as? String
            let assignedEventId = data["assignedEventId"] as? String
            if role == "security" && assignedEventId == event.id {
                return true
            }
        } catch {
            print("❌ Failed to check authorization: \(error.localizedDescription)")
        }
        return false
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let code = metadataObject.stringValue else {
            return
        }
        
        Task { @MainActor in
            await verifyCode(code)
        }
    }
}
