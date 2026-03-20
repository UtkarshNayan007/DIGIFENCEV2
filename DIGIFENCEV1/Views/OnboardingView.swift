//
//  OnboardingView.swift
//  DIGIFENCEV1
//
//  Premium multi-page onboarding with fluid animations.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var hasCompletedOnboarding: Bool
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 0) {
                // Pages
                TabView(selection: $viewModel.currentPage) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: viewModel.currentPage) {
                    HapticManager.shared.selection()
                }
                
                // Bottom Controls
                bottomControls
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            Color(.systemBackground)
            
            // Animated gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -50, y: -300)
                .blur(radius: 80)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 100, y: 400)
                .blur(radius: 60)
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page Indicators
            HStack(spacing: 10) {
                ForEach(0..<viewModel.pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == viewModel.currentPage ? Color.dfAccent : Color(.systemGray4))
                        .frame(width: index == viewModel.currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.currentPage)
                }
            }
            .padding(.bottom, 8)
            
            // Continue Button
            DFPrimaryButton(
                title: viewModel.isLastPage ? "Get Started" : "Continue",
                icon: viewModel.isLastPage ? "arrow.right.circle.fill" : nil
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if viewModel.isLastPage {
                        viewModel.completeOnboarding()
                        hasCompletedOnboarding = true
                    } else {
                        viewModel.nextPage()
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Skip Button
            if !viewModel.isLastPage {
                Button("Skip") {
                    HapticManager.shared.light()
                    viewModel.completeOnboarding()
                    hasCompletedOnboarding = true
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            }
            
            Spacer().frame(height: 24)
        }
    }
}

// MARK: - Onboarding Page

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var iconAppeared = false
    @State private var textAppeared = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon Container
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.dfAccent.opacity(0.06))
                    .frame(width: 220, height: 220)
                    .scaleEffect(iconAppeared ? 1.0 : 0.5)
                
                // Inner circle
                Circle()
                    .fill(Color.dfAccent.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconAppeared ? 1.0 : 0.6)
                
                // Icon or Logo
                if page.icon == "AppLogo" {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.cyan.opacity(0.3), radius: 16, y: 8)
                } else {
                    Image(systemName: page.icon)
                        .font(.system(size: 70, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .scaleEffect(iconAppeared ? 1.0 : 0.3)
            .opacity(iconAppeared ? 1.0 : 0)
            
            // Text Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .opacity(textAppeared ? 1.0 : 0)
            .offset(y: textAppeared ? 0 : 20)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            iconAppeared = false
            textAppeared = false
            
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
                iconAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textAppeared = true
            }
        }
    }
}
