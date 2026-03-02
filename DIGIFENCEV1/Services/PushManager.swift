//
//  PushManager.swift
//  DIGIFENCEV1
//
//  FCM token management, APNs registration, and notification handling.
//

import Foundation
import Combine
import SwiftUI
import UIKit
import FirebaseMessaging
import UserNotifications

final class PushManager: NSObject, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    static let shared = PushManager()
    
    @Published var fcmToken: String?
    @Published var permissionGranted = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permission Request
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            DispatchQueue.main.async {
                self.permissionGranted = granted
            }
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("❌ Push permission error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - APNs Token Registration
    
    func setAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("📱 FCM Token: \(token)")
        
        DispatchQueue.main.async {
            self.fcmToken = token
        }
        
        // Update token in Firestore
        Task {
            do {
                try await FirebaseManager.shared.updateFCMToken(token)
            } catch {
                print("❌ Failed to update FCM token: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "exit_warning",
           let ticketId = userInfo["ticketId"] as? String {
            print("📲 User tapped exit warning for ticket: \(ticketId)")
            // Post notification for UI to handle navigation
            NotificationCenter.default.post(
                name: .didTapExitWarning,
                object: nil,
                userInfo: ["ticketId": ticketId]
            )
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapExitWarning = Notification.Name("DigiFence.didTapExitWarning")
}
