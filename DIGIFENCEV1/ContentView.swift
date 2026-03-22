//
//  ContentView.swift
//  DIGIFENCEV1
//
//  Root routing: Onboarding → Login → Biometric Lock → MainTabView.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "DigiFence_OnboardingComplete")

    var body: some View {
        Group {
            if firebase.isLoading {
                SplashView()
            } else if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if firebase.currentUser == nil {
                LoginView()
            } else if !firebase.isBiometricAuthenticated {
                BiometricLockView()
            } else {
                MainTabView()
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: firebase.isLoggedIn)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: firebase.isBiometricAuthenticated)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: hasCompletedOnboarding)
    }
}

// MARK: - Splash

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: DFSpacing.xl) {
                DFAnimatedLogo(size: 88, cornerRadius: 22)
                VStack(spacing: DFSpacing.sm) {
                    Text("DigiFence")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Secure Event Access")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                ProgressView()
                    .controlSize(.regular)
                    .tint(.dfAccent)
                    .padding(.top, DFSpacing.md)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) { appeared = true }
        }
    }
}

// MARK: - Biometric Lock

struct BiometricLockView: View {
    @StateObject private var authVM = AuthViewModel()
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var isAuthenticating = false
    @State private var showSignOutConfirm = false
    @State private var hasAttemptedAutoUnlock = false
    @State private var appeared = false

    private let biometric = BiometricAuthManager.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: DFSpacing.xxl) {
                Spacer()

                DFAnimatedLogo(size: 80, cornerRadius: 20)

                VStack(spacing: DFSpacing.sm) {
                    Text("Welcome Back")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(firebase.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(appeared ? 1 : 0)

                Text("Authenticate to continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
                    .opacity(appeared ? 1 : 0)

                Spacer()

                VStack(spacing: DFSpacing.lg) {
                    DFPrimaryButton(
                        title: "Unlock with \(biometric.biometricName)",
                        icon: biometric.biometricType == .faceID ? "faceid" : "touchid",
                        isLoading: isAuthenticating
                    ) {
                        Task {
                            isAuthenticating = true
                            await authVM.unlockWithBiometrics()
                            isAuthenticating = false
                        }
                    }
                    .padding(.horizontal, DFSpacing.xl)

                    Button("Sign Out") {
                        HapticManager.shared.light()
                        showSignOutConfirm = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, DFSpacing.xxxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { appeared = true }
            guard !hasAttemptedAutoUnlock else { return }
            hasAttemptedAutoUnlock = true
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                isAuthenticating = true
                await authVM.unlockWithBiometrics()
                isAuthenticating = false
            }
        }
        .alert("Error", isPresented: $authVM.showError) {
            Button("Try Again") {
                Task { isAuthenticating = true; await authVM.unlockWithBiometrics(); isAuthenticating = false }
            }
            Button("Sign Out", role: .destructive) { authVM.signOut() }
        } message: {
            Text(authVM.errorMessage ?? "Authentication failed.")
        }
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
