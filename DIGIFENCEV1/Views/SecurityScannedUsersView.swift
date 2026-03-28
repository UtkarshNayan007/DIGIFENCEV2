//
//  SecurityScannedUsersView.swift
//  DIGIFENCEV1
//
//  Shows the list of users this security person has scanned/checked-in,
//  with real-time updates as new scans happen.
//

import SwiftUI

struct SecurityScannedUsersView: View {
    @StateObject private var viewModel = SecurityScannedUsersViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading && viewModel.guests.isEmpty {
                VStack(spacing: DFSpacing.lg) {
                    ProgressView().controlSize(.large).tint(.dfAccent)
                    Text("Loading scanned users...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.guests.isEmpty {
                DFEmptyState(
                    icon: "person.2.slash",
                    title: "No Scans Yet",
                    message: "Users you check in will appear here in real time."
                )
            } else {
                ScrollView {
                    // Summary
                    HStack(spacing: DFSpacing.md) {
                        ScanStatCard(
                            value: "\(viewModel.guests.count)",
                            label: "Total Scanned",
                            icon: "qrcode.viewfinder",
                            color: .dfAccent
                        )
                        ScanStatCard(
                            value: "\(viewModel.guests.filter { $0.insideFence }.count)",
                            label: "Inside Fence",
                            icon: "location.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)

                    LazyVStack(spacing: DFSpacing.sm) {
                        ForEach(Array(viewModel.guests.enumerated()), id: \.element.id) { index, guest in
                            ScannedGuestRow(guest: guest)
                                .entranceAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.md)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    viewModel.stopListening()
                    viewModel.startListening()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        .navigationTitle("Scanned Users")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Scan Stat Card

private struct ScanStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
    }
}

// MARK: - Scanned Guest Row

private struct ScannedGuestRow: View {
    let guest: ScannedGuest

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.dfAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(guest.userName.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.dfAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(guest.userName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(guest.userEmail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                    Text(guest.eventTitle)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.blue)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: guest.insideFence ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 10))
                    Text(guest.insideFence ? "Inside" : "Exited")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(guest.insideFence ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((guest.insideFence ? Color.green : Color.orange).opacity(0.1))
                .clipShape(Capsule())

                // Scanned time
                if let scannedAt = guest.scannedAt {
                    Text(scannedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DFSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}
