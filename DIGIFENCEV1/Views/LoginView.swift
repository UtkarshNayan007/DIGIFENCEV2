//
//  LoginView.swift
//  DIGIFENCEV1
//
//  Clean, minimal login/signup with email verification support.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: max(60, geo.size.height * 0.1))

                        // Logo
                        DFAnimatedLogo(size: 80, cornerRadius: 20)
                            .padding(.bottom, 12)

                        VStack(spacing: 4) {
                            Text("DigiFence")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("Secure Event Access")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 36)

                        // Form Card
                        formCard
                            .padding(.horizontal, 24)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)

                        // Toggle
                        toggleFooter
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) { appeared = true }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 16) {
            if viewModel.showVerificationSent {
                verificationBanner
            }

            // Mode Toggle
            modeToggle

            // Fields
            VStack(spacing: 12) {
                if isSignUp {
                    DFTextField(icon: "person", placeholder: "Full Name", text: $viewModel.displayName)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                DFTextField(icon: "envelope", placeholder: "Email", text: $viewModel.email, keyboardType: .emailAddress)
                DFSecureField(icon: "lock", placeholder: "Password", text: $viewModel.password)
                if isSignUp {
                    DFPhoneField(icon: "phone", placeholder: "Phone Number", text: $viewModel.phoneNumber)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Primary Action
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
            .padding(.top, 4)

            if viewModel.showVerificationSent && !isSignUp {
                Button {
                    Task { await viewModel.resendVerificationEmail() }
                } label: {
                    Label("Resend Verification Email", systemImage: "envelope.arrow.triangle.branch")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.dfAccent)
                }
            }

            // Divider
            HStack(spacing: 14) {
                Rectangle().fill(Color(.separator).opacity(0.3)).frame(height: 0.5)
                Text("or").font(.system(size: 13, weight: .medium)).foregroundColor(Color(.tertiaryLabel))
                Rectangle().fill(Color(.separator).opacity(0.3)).frame(height: 0.5)
            }
            .padding(.vertical, 4)

            // Google
            DFSecondaryButton(title: "Continue with Google", icon: "g.circle.fill") {
                Task { await viewModel.signInWithGoogle() }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach([("Sign In", false), ("Sign Up", true)], id: \.0) { title, mode in
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSignUp = mode
                        viewModel.showVerificationSent = false
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSignUp == mode ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Group {
                                if isSignUp == mode {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DFGradients.accentHorizontal)
                                }
                            }
                        )
                }
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - Verification Banner

    private var verificationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Verification Sent")
                    .font(.system(size: 14, weight: .semibold))
                Text(viewModel.verificationMessage ?? "Check your email.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                .fill(Color.green.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                        .stroke(Color.green.opacity(0.15), lineWidth: 1)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Toggle Footer

    private var toggleFooter: some View {
        Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isSignUp.toggle()
                viewModel.showVerificationSent = false
            }
        } label: {
            HStack(spacing: 4) {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(.secondary)
                Text(isSignUp ? "Sign In" : "Sign Up")
                    .foregroundColor(.dfAccent)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14))
        }
    }
}

// MARK: - Phone Field

struct DFPhoneField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isValid = true

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? .dfAccent : (isValid ? .secondary : .red))
                .frame(width: 22)
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .keyboardType(.phonePad)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    validatePhone(newValue)
                }
            if !text.isEmpty {
                Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(isValid ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DFSpacing.lg)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                .stroke(isFocused ? Color.dfAccent.opacity(0.5) : (isValid ? Color.clear : Color.red.opacity(0.4)), lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func validatePhone(_ phone: String) {
        guard !phone.isEmpty else { isValid = true; return }
        let cleaned = phone.replacingOccurrences(of: "[\\s\\-\\(\\)]", with: "", options: .regularExpression)
        let pred = NSPredicate(format: "SELF MATCHES %@", "^\\+?[0-9]{10,15}$")
        withAnimation(.easeInOut(duration: 0.2)) { isValid = pred.evaluate(with: cleaned) }
    }
}
