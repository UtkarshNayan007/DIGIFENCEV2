//
//  LoginView.swift
//  DIGIFENCEV1
//
//  Premium professional login experience with phone number support.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    @State private var logoAppeared = false
    @State private var formAppeared = false
    @State private var backgroundAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated Background
                animatedBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: max(50, geometry.size.height * 0.06))
                        
                        // Logo Section
                        logoSection
                            .padding(.bottom, 36)
                        
                        // Main Content Card
                        mainContentCard
                            .padding(.horizontal, 20)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear(perform: animateEntrance)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }
    
    // MARK: - Animated Background
    
    private var animatedBackground: some View {
        ZStack {
            Color(.systemBackground)
            
            // Animated gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 450, height: 450)
                .offset(x: backgroundAnimating ? -80 : -120, y: backgroundAnimating ? -180 : -220)
                .blur(radius: 70)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: backgroundAnimating ? 130 : 170, y: backgroundAnimating ? 320 : 280)
                .blur(radius: 60)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: backgroundAnimating ? -150 : -180, y: backgroundAnimating ? 200 : 240)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                backgroundAnimating = true
            }
        }
    }

    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 18) {
            // Animated Logo
            ZStack {
                // Glow ring
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 25)
                    .scaleEffect(logoAppeared ? 1.0 : 0.5)
                
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Color.cyan.opacity(0.4), radius: 28, y: 12)
                    .scaleEffect(logoAppeared ? 1.0 : 0.3)
            }
            
            VStack(spacing: 8) {
                Text("DigiFence")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Secure Event Access")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .opacity(logoAppeared ? 1 : 0)
            .offset(y: logoAppeared ? 0 : 15)
        }
    }
    
    // MARK: - Main Content Card
    
    private var mainContentCard: some View {
        VStack(spacing: 24) {
            // Verification Banner
            if viewModel.showVerificationSent {
                verificationBanner
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Mode Toggle Header
            modeToggleHeader
            
            // Form Fields
            formFields
            
            // Primary Action
            primaryActionButton
            
            // Resend Verification
            if viewModel.showVerificationSent && !isSignUp {
                resendVerificationButton
            }
            
            // Divider
            orDivider
            
            // Google Sign In (Apple removed)
            googleSignInButton
            
            // Toggle Sign In/Up
            toggleButton
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
        )
        .opacity(formAppeared ? 1 : 0)
        .offset(y: formAppeared ? 0 : 40)
    }

    // MARK: - Mode Toggle Header
    
    private var modeToggleHeader: some View {
        HStack(spacing: 0) {
            ForEach([("Sign In", false), ("Sign Up", true)], id: \.0) { title, isSignUpMode in
                Button(action: {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSignUp = isSignUpMode
                        viewModel.showVerificationSent = false
                    }
                }) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSignUp == isSignUpMode ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            Group {
                                if isSignUp == isSignUpMode {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Form Fields
    
    private var formFields: some View {
        VStack(spacing: 14) {
            if isSignUp {
                DFTextField(icon: "person", placeholder: "Full Name", text: $viewModel.displayName)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            DFTextField(icon: "envelope", placeholder: "Email Address", text: $viewModel.email, keyboardType: .emailAddress)
            
            DFSecureField(icon: "lock", placeholder: "Password", text: $viewModel.password)
            
            if isSignUp {
                DFPhoneField(icon: "phone", placeholder: "Phone Number", text: $viewModel.phoneNumber)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
    
    // MARK: - Primary Action Button
    
    private var primaryActionButton: some View {
        DFPrimaryButton(
            title: isSignUp ? "Create Account" : "Sign In",
            icon: isSignUp ? "person.badge.plus" : "arrow.right",
            isLoading: viewModel.isLoading
        ) {
            Task {
                if isSignUp { await viewModel.signUp() }
                else { await viewModel.signIn() }
            }
        }
    }
    
    // MARK: - Resend Verification
    
    private var resendVerificationButton: some View {
        Button(action: {
            HapticManager.shared.light()
            Task { await viewModel.resendVerificationEmail() }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.arrow.triangle.branch")
                    .font(.system(size: 14, weight: .medium))
                Text("Resend Verification Email")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.dfAccent)
        }
        .transition(.opacity)
    }

    // MARK: - Or Divider
    
    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 0.5)
            
            Text("or continue with")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.tertiaryLabel))
            
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 0.5)
        }
    }
    
    // MARK: - Google Sign In Button
    
    private var googleSignInButton: some View {
        Button(action: {
            HapticManager.shared.light()
            Task { await viewModel.signInWithGoogle() }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .medium))
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(DFScaleButtonStyle())
    }
    
    // MARK: - Toggle Button
    
    private var toggleButton: some View {
        Button(action: {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isSignUp.toggle()
                viewModel.showVerificationSent = false
            }
        }) {
            HStack(spacing: 6) {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(.secondary)
                Text(isSignUp ? "Sign In" : "Sign Up")
                    .foregroundColor(.dfAccent)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14))
        }
    }
    
    // MARK: - Verification Banner
    
    private var verificationBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Verification Sent")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(viewModel.verificationMessage ?? "Check your email inbox.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Animation
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
            logoAppeared = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
            formAppeared = true
        }
    }
}


// MARK: - Phone Number Field Component

struct DFPhoneField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isValid: Bool = true

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? .dfAccent : (isValid ? .secondary : .red))
                .frame(width: 24)
                .animation(.easeInOut(duration: 0.2), value: isFocused)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .keyboardType(.phonePad)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    // Format and validate as user types
                    validatePhone(newValue)
                }
            
            // Validation indicator
            if !text.isEmpty {
                Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isValid ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DFSpacing.lg)
        .frame(height: 56)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                .stroke(isFocused ? Color.dfAccent.opacity(0.6) : (isValid ? Color.clear : Color.red.opacity(0.5)), lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
    
    private func validatePhone(_ phone: String) {
        if phone.isEmpty {
            isValid = true
            return
        }
        let cleanedPhone = phone.replacingOccurrences(of: "[\\s\\-\\(\\)]", with: "", options: .regularExpression)
        let phoneRegex = "^\\+?[0-9]{10,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        withAnimation(.easeInOut(duration: 0.2)) {
            isValid = phonePredicate.evaluate(with: cleanedPhone)
        }
    }
}
