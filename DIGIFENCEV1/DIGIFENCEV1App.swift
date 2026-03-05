//
//  DIGIFENCEV1App.swift
//  DIGIFENCEV1
//
//  Main app entry point with Firebase setup, FCM, and background handling.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // NOTE: App Check is intentionally NOT configured here.
        // To use App Check in production, you must:
        // 1. Set up AppCheckDebugProviderFactory (for simulators) or DeviceCheck/AppAttest (for devices)
        // 2. Register debug tokens in Firebase Console → App Check → Apps
        // 3. Enforce App Check for Firestore in Firebase Console → App Check → APIs
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure push notifications
        PushManager.shared.configure()
        
        // Location authorization will be requested when needed (e.g. ticket activation)
        // Not requested eagerly to avoid crashes on simulator
        
        return true
    }
    
    // MARK: - APNs Token Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushManager.shared.setAPNSToken(deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
    }
}

@main
struct DIGIFENCEV1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
