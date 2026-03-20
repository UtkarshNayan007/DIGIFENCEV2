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
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: firebase.isLoggedIn)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: firebase.isBiometricAuthenticated)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: hasCompletedOnboarding)
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .opacity(glowOpacity)
            
            VStack(spacing: DFSpacing.xl) {
                // Logo
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .opacity(glowOpacity)
                    
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.cyan.opacity(0.35), radius: 24, y: 10)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // Text
                VStack(spacing: DFSpacing.sm) {
                    Text("DigiFence")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Secure Event Access")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(textOpacity)
                
                // Loading indicator
                ProgressView()
                    .controlSize(.regular)
                    .tint(.dfAccent)
                    .padding(.top, DFSpacing.lg)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                glowOpacity = 1.0
            }
        }
    }
}


// MARK: - Biometric Lock Screen

struct BiometricLockView: View {
    @StateObject private var authVM = AuthViewModel()
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var isAuthenticating = false
    @State private var showSignOutConfirm = false
    @State private var hasAttemptedAutoUnlock = false
    @State private var appeared = false
    @State private var glowPulse = false
    
    private let biometric = BiometricAuthManager.shared
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: DFSpacing.xxl) {
                Spacer()
                
                // Logo & Welcome
                VStack(spacing: DFSpacing.xl) {
                    // Logo with glow
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .blur(radius: 30)
                            .scaleEffect(glowPulse ? 1.1 : 1.0)
                        
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: Color.cyan.opacity(0.3), radius: 20, y: 8)
                    }
                    .scaleEffect(appeared ? 1.0 : 0.7)
                    .opacity(appeared ? 1.0 : 0)
                    
                    // Welcome text
                    VStack(spacing: DFSpacing.sm) {
                        Text("Welcome Back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(firebase.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
                
                // Instruction
                Text("Authenticate to continue")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
                    .opacity(appeared ? 1.0 : 0)
                
                Spacer()
                
                // Unlock Button
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
                    
                    // Sign Out
                    Button("Sign Out") {
                        HapticManager.shared.light()
                        showSignOutConfirm = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .opacity(appeared ? 1.0 : 0)
                .padding(.bottom, DFSpacing.xxxl)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            
            // Auto-unlock
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
                Task {
                    isAuthenticating = true
                    await authVM.unlockWithBiometrics()
                    isAuthenticating = false
                }
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
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            Color(.systemBackground)
            
            // Gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -80, y: -150)
                .blur(radius: 60)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: 100, y: 250)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
    }
}
