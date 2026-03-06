//
//  ContentView.swift
//  DIGIFENCEV1
//
//  Root view: routes between Onboarding → Login → Biometric Lock → MainTabView.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "DigiFence_OnboardingComplete")
    
    var body: some View {
        Group {
            if firebase.isLoading {
                // Loading / Splash state
                splashView
            } else if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if firebase.currentUser == nil {
                // Not signed in
                LoginView()
            } else if !firebase.isBiometricAuthenticated {
                // Signed in but not biometric-verified (app relaunch)
                BiometricLockView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: firebase.isLoggedIn)
        .animation(.easeInOut(duration: 0.3), value: firebase.isBiometricAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
    
    private var splashView: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Text("DigiFence")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                ProgressView()
                    .tint(.cyan)
            }
        }
    }
}

// MARK: - Biometric Lock Screen

/// Shown when the user is Firebase-authenticated but hasn't passed biometric MFA
/// (e.g., app relaunch, returning from background).
struct BiometricLockView: View {
    @StateObject private var authVM = AuthViewModel()
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var isAuthenticating = false
    @State private var showSignOutConfirm = false
    @State private var hasAttemptedAutoUnlock = false
    
    private let biometric = BiometricAuthManager.shared
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(spacing: 8) {
                    Text("Welcome Back")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(firebase.currentUser?.email ?? "")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Text("Authenticate to continue")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                // Unlock button
                Button(action: {
                    Task {
                        isAuthenticating = true
                        await authVM.unlockWithBiometrics()
                        isAuthenticating = false
                    }
                }) {
                    HStack(spacing: 12) {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: biometric.biometricType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 22))
                            Text("Unlock with \(biometric.biometricName)")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 24)
                
                // Sign out option
                Button("Sign Out") {
                    showSignOutConfirm = true
                }
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Auto-trigger biometric once on appear (not on re-renders)
            guard !hasAttemptedAutoUnlock else { return }
            hasAttemptedAutoUnlock = true
            Task {
                isAuthenticating = true
                await authVM.unlockWithBiometrics()
                isAuthenticating = false
            }
        }
        .alert("Error", isPresented: $authVM.showError) {
            Button("Try Again") {
                Task {
                    isAuthenticating = true
                    await authVM.unlockWithBiometrics()
                    isAuthenticating = false
                }
            }
            Button("Sign Out", role: .destructive) {
                authVM.signOut()
            }
        } message: {
            Text(authVM.errorMessage ?? "Authentication failed.")
        }
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authVM.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
