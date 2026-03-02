//
//  FirebaseStorageManager.swift
//  DIGIFENCEV1
//
//  Handles uploading image data to Firebase Storage and returning the download URL.
//

import Foundation
import FirebaseStorage

enum StorageError: Error {
    case uploadFailed(String)
    case maxConcurrentUploadsReached
    case noData
}

final class FirebaseStorageManager {
    static let shared = FirebaseStorageManager()
    
    private let storage = Storage.storage()
    
    private init() {}
    
    /// Uploads an image to the 'events/{eventId}/thumbnail.jpg' path.
    /// Returns the download URL as a String.
    func uploadEventThumbnail(eventId: String, imageData: Data) async throws -> String {
        let storageRef = storage.reference().child("events/\(eventId)/thumbnail.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        // Retrieve download URL
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
}
