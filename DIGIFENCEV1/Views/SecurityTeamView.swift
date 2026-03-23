//
//  SecurityTeamView.swift
//  DIGIFENCEV1
//
//  Admin view for managing security personnel — create, list, remove, reset passwords.
//

import SwiftUI

struct SecurityTeamView: View {
    @StateObject private var viewModel = SecurityTeamViewModel()
    @State private var personToDelete: SecurityPerson?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading && viewModel.personnel.isEmpty {
                VStack(spacing: DFSpacing.lg) {
                    ProgressView().controlSize(.large).tint(.dfAccent)
                    Text("Loading team...").font(.subheadline).foregroundColor(.secondary)
                }
            } else if viewModel.personnel.isEmpty {
                DFEmptyState(
                    icon: "shield.slash",
                    title: "No Security Team",
                    message: "Add security personnel to handle event check-ins."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DFSpacing.sm) {
                        ForEach(Array(viewModel.personnel.enumerated()), id: \.element.id) { index, person in
                            NavigationLink {
                                AdminSecurityGuestListView(securityPerson: person)
                            } label: {
                                SecurityPersonRow(
                                    person: person,
                                    onResetPassword: {
                                        Task { await viewModel.resetPasswordFor(person) }
                                    },
                                    onDelete: {
                                        personToDelete = person
                                        showDeleteConfirm = true
                                    }
                                )
                                .entranceAnimation(index: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DFSpacing.lg)
                    .padding(.top, DFSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Security Team")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.shared.light()
                    viewModel.showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.dfAccent)
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateSecuritySheet(viewModel: viewModel)
        }
        .alert("Account Created ✅", isPresented: $viewModel.showCreatedSuccess) {
            Button("OK") {}
        } message: {
            Text("Security personnel account created successfully. They can now log in with the credentials you provided.")
        }
        .alert("Password Reset", isPresented: $viewModel.showResetAlert) {
            Button("Copy Password") {
                UIPasteboard.general.string = viewModel.resetPassword
                HapticManager.shared.success()
            }
            Button("OK") {}
        } message: {
            Text("New password:\n\n\(viewModel.resetPassword ?? "")\n\nShare this with the security person.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Remove Security Person", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let person = personToDelete {
                    Task { await viewModel.removePerson(person) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \(personToDelete?.name ?? "") and revoke their access.")
        }
        .task { await viewModel.fetchPersonnel() }
    }
}

// MARK: - Security Person Row

private struct SecurityPersonRow: View {
    let person: SecurityPerson
    let onResetPassword: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DFSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.dfAccent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(String(person.name.prefix(1)).uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.dfAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(person.email)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    if let eventTitle = person.assignedEventTitle {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 9))
                            Text(eventTitle)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .lineLimit(1)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("No event assigned")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.orange)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        HapticManager.shared.light()
                        onResetPassword()
                    } label: {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Button {
                        HapticManager.shared.light()
                        onDelete()
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(DFSpacing.md)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
    }
}

// MARK: - Create Security Sheet

private struct CreateSecuritySheet: View {
    @ObservedObject var viewModel: SecurityTeamViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DFSpacing.xl) {
                        VStack(spacing: DFSpacing.lg) {
                            DFIconBadge(icon: "shield.lefthalf.filled", color: .dfAccent, size: 64, iconSize: 28)
                            VStack(spacing: 4) {
                                Text("Add Security Person")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                Text("Create login credentials for event check-ins")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        VStack(spacing: DFSpacing.md) {
                            DFTextField(icon: "person.fill", placeholder: "Full Name", text: $viewModel.newName)
                            DFTextField(icon: "envelope.fill", placeholder: "Email Address", text: $viewModel.newEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            DFTextField(icon: "lock.fill", placeholder: "Password (min 6 chars)", text: $viewModel.newPassword)
                        }

                        // Event Assignment
                        VStack(alignment: .leading, spacing: DFSpacing.sm) {
                            Text("Assign to Event")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            if viewModel.availableEvents.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    Text("No active events found")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ForEach(viewModel.availableEvents) { event in
                                    Button {
                                        HapticManager.shared.selection()
                                        if viewModel.selectedEventId == event.id {
                                            viewModel.selectedEventId = nil
                                        } else {
                                            viewModel.selectedEventId = event.id
                                        }
                                    } label: {
                                        HStack(spacing: DFSpacing.sm) {
                                            Image(systemName: viewModel.selectedEventId == event.id ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(viewModel.selectedEventId == event.id ? .green : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                if let code = event.eventCode {
                                                    Text("Code: \(code)")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(DFSpacing.sm)
                                        .background(
                                            viewModel.selectedEventId == event.id
                                                ? Color.green.opacity(0.08)
                                                : Color(.tertiarySystemGroupedBackground)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.sm, style: .continuous))
                                    }
                                }
                            }
                        }

                        DFPrimaryButton(
                            title: "Create Account",
                            icon: "plus.circle.fill",
                            isLoading: viewModel.isCreating,
                            colors: [.dfAccent, .blue]
                        ) {
                            Task { await viewModel.createPerson() }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, DFSpacing.xl)
                    .padding(.top, DFSpacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await viewModel.fetchEvents() }
        }
    }
}
