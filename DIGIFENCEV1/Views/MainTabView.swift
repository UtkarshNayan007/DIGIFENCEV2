//
//  MainTabView.swift
//  DIGIFENCEV1
//
//  TabView with Events, My Passes, Admin (conditional), Profile tabs.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Events Tab
            NavigationView {
                EventsListView()
            }
            .tabItem {
                Label("Events", systemImage: "calendar.badge.plus")
            }
            .tag(0)
            
            // My Passes Tab
            NavigationView {
                MyPassView()
            }
            .tabItem {
                Label("My Passes", systemImage: "ticket")
            }
            .tag(1)
            
            // Admin Tab (only for admin users)
            if firebase.appUser?.isAdmin == true {
                NavigationView {
                    AdminMapView()
                }
                .tabItem {
                    Label("Create", systemImage: "map.fill")
                }
                .tag(2)
                
                NavigationView {
                    AdminDashboardView()
                }
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(3)
            }
            
            // Profile Tab
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(4)
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var firebase = FirebaseManager.shared
    @StateObject private var authVM = AuthViewModel()
    @State private var showSignOutConfirm = false
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                        
                        Text(String(firebase.appUser?.displayName.prefix(1).uppercased() ?? "?"))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    // User info
                    VStack(spacing: 4) {
                        Text(firebase.appUser?.displayName ?? "User")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(firebase.appUser?.email ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                        
                        if firebase.appUser?.isAdmin == true {
                            Text("ADMIN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(Capsule())
                                .padding(.top, 4)
                        }
                    }
                    
                    // Info cards
                    VStack(spacing: 1) {
                        ProfileInfoRow(icon: "key.fill", label: "Biometric Key", value: firebase.appUser?.publicKey != nil ? "Enrolled ✓" : "Not enrolled")
                        ProfileInfoRow(icon: "bell.fill", label: "Push Notifications", value: PushManager.shared.permissionGranted ? "Enabled" : "Disabled")
                        ProfileInfoRow(icon: "location.fill", label: "Location Access", value: LocationManager.shared.hasLocationPermission ? "Granted" : "Not granted")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    
                    // Re-enroll biometrics
                    if firebase.appUser?.publicKey == nil {
                        Button(action: {
                            Task {
                                do {
                                    let publicKey = try SecureEnclaveManager.shared.generateKeyPair()
                                    try await FirebaseManager.shared.updatePublicKey(publicKey)
                                } catch {
                                    print("Key generation failed: \(error)")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Enroll Biometrics")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.cyan.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Sign out
                    Button(action: { showSignOutConfirm = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    
                    // Version
                    Text("DigiFence v1.0")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.top, 20)
                    
                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authVM.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 30)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
    }
}
