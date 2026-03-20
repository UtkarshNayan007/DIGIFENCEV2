//
//  EventsListView.swift
//  DIGIFENCEV1
//
//  Scrollable list of active events with search.
//

import SwiftUI
import FirebaseCore

struct EventsListView: View {
    @StateObject private var viewModel = EventsViewModel()
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.accentColor)
            } else if viewModel.events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(viewModel.filteredEvents(searchText: searchText).enumerated()), id: \.element.id) { index, event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                EventCardView(event: event)
                            }
                            .buttonStyle(CardButtonStyle())
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: viewModel.events.count)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search events...")
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Events Available", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Check back later for upcoming events.")
        }
    }
}

// MARK: - Card Button Style (press effect)

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue { HapticManager.shared.light() }
            }
    }
}

// MARK: - Event Card

struct EventCardView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            if let imageURLString = event.thumbnailURL, let url = URL(string: imageURLString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    case .failure:
                        placeholderImage
                    default:
                        Rectangle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(height: 160)
                            .overlay(ProgressView().controlSize(.small))
                    }
                }
            } else {
                placeholderImage
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Status dot
                    Circle()
                        .fill(event.isActive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
                
                // Metadata row
                HStack(spacing: 14) {
                    Label("\(event.polygonCoordinates.count)-pt fence", systemImage: "pentagon")
                        .font(.caption)
                        .foregroundStyle(.tint)
                    
                    if let capacity = event.capacity {
                        Label("\(capacity)", systemImage: "person.3.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let startsAt = event.startsAt {
                        Label(
                            startsAt.dateValue().formatted(date: .abbreviated, time: .shortened),
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
                
                // Price
                if let price = event.ticketPrice, price > 0 {
                    Text("₹\(Int(price))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Text("Free")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), Color.blue.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 100)
            .overlay(
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
            )
    }
}
