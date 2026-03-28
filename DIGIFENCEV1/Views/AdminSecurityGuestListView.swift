//
//  AdminSecurityGuestListView.swift
//  DIGIFENCEV1
//
//  Shows the list of guests permitted inside the fence by a specific security person.
//

import SwiftUI

struct AdminSecurityGuestListView: View {
    let securityPerson: SecurityPerson
    @StateObject private var viewModel = AdminSecurityGuestListViewModel()
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.guests.isEmpty {
                VStack(spacing: DFSpacing.lg) {
                    ProgressView().controlSize(.large).tint(.dfAccent)
                    Text("Loading guests...").font(.subheadline).foregroundColor(.secondary)
                }
            } else if viewModel.guests.isEmpty {
                DFEmptyState(
                    icon: "person.2.slash",
                    title: "No Check-Ins Yet",
                    message: "\(securityPerson.name) hasn't checked in any guests yet."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.sm) {
                        ForEach(Array(viewModel.guests.enumerated()), id: \.element.uid) { index, user in
                            PermittedGuestRow(user: user)
                                .entranceAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Guests Checked In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Guests Scanned By")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(securityPerson.name)
                        .font(.headline)
                }
            }
        }
        .onAppear {
            viewModel.listenForScannedGuests(securityUid: securityPerson.id, eventId: nil)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }
}

private struct PermittedGuestRow: View {
    let user: AppUser
    
    var body: some View {
        HStack(spacing: DFSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.dfAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.dfAccent)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(user.email)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text("Inside")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}
