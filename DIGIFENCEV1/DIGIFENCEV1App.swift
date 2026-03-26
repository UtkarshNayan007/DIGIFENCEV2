//
//  DIGIFENCEV1App.swift
//  DIGIFENCEV1
//
//  Main app entry point with Firebase setup, FCM, and background handling.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure App Check BEFORE FirebaseApp.configure()
        // Using Debug Provider for development (no Apple Developer Program required)
        // On first launch, check Xcode console for a line like:
        //   [Firebase/AppCheck] App Check debug token: XXXXXXXX-XXXX-...
        // Register that token in Firebase Console → App Check → Apps → Manage debug tokens
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure push notifications
        PushManager.shared.configure()
        
        // Configure global URLCache for image caching (50MB memory, 250MB disk)
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 250 * 1024 * 1024
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, directory: nil)
        URLCache.shared = cache
        
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
                .tint(.cyan)
        }
    }
}
