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
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("", text: $searchText, prompt: Text("Search events...").foregroundColor(.white.opacity(0.3)))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.events.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No Events Available")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Check back later for upcoming events.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredEvents(searchText: searchText)) { event in
                                NavigationLink(destination: EventDetailView(event: event)) {
                                    EventCardView(event: event)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}

// MARK: - Event Card

struct EventCardView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail Image
            if let imageURLString = event.thumbnailURL, let url = URL(string: imageURLString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 140)
                        .overlay(ProgressView().tint(.white))
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Active indicator
                    Circle()
                        .fill(event.isActive ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }
                
                HStack(spacing: 16) {
                    Label("\(event.polygonCoordinates.count)-pt fence", systemImage: "pentagon")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan.opacity(0.8))
                    
                    if let capacity = event.capacity {
                        Label("\(capacity)", systemImage: "person.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    if let startsAt = event.startsAt {
                        Label(
                            startsAt.dateValue().formatted(date: .abbreviated, time: .shortened),
                            systemImage: "calendar"
                        )
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                if let price = event.ticketPrice, price > 0 {
                    Text("₹\(Int(price))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("Free")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
