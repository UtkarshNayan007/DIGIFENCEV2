//
//  ContentView.swift
//  DIGIFENCEV1
//
//  Root view: routes between Onboarding → Login → MainTabView based on auth state.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "DigiFence_OnboardingComplete")
    
    var body: some View {
        Group {
            if firebase.isLoading {
                // Loading state
                ZStack {
                    Color(red: 0.05, green: 0.05, blue: 0.12)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("DigiFence")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        ProgressView()
                            .tint(.cyan)
                    }
                }
            } else if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if !firebase.isLoggedIn {
                LoginView()
            } else if firebase.appUser?.role == .admin {
                AdminDashboardView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: firebase.isLoggedIn)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
}
