//
//  SecurityProfileView.swift
//  DIGIFENCEV1
//
//  Simple profile view for security personnel — shows identity and sign-out.
//

import SwiftUI
import FirebaseAuth

struct SecurityProfileView: View {
    @ObservedObject private var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @State private var showLogoutConfirm = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: DFSpacing.xl) {
                Spacer()

                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.dfAccent, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text(firebase.appUser?.displayName ?? "Security")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(firebase.appUser?.email ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 11))
                        Text("Security Personnel")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.dfAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.dfAccent.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()

                // Sign Out
                Button {
                    HapticManager.shared.light()
                    showLogoutConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                .padding(.bottom, DFSpacing.xl)
            }
            .padding(.horizontal, DFSpacing.xl)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authVM.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}
