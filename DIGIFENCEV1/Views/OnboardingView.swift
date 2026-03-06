//
//  OnboardingView.swift
//  DIGIFENCEV1
//
//  Multi-page onboarding with SF Symbol illustrations.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $viewModel.currentPage) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 30) {
                            Spacer()
                            
                            // Icon with animated glow
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.cyan.opacity(0.3),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 100
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                
                                if page.icon == "AppLogo" {
                                    Image("AppLogo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
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
                            
                            VStack(spacing: 16) {
                                Text(page.title)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(page.description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            
                            Spacer()
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentPage ? Color.cyan : Color.white.opacity(0.3))
                            .frame(width: index == viewModel.currentPage ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
                    }
                }
                .padding(.bottom, 30)
                
                // Button
                Button(action: {
                    withAnimation {
                        if viewModel.isLastPage {
                            viewModel.completeOnboarding()
                            hasCompletedOnboarding = true
                        } else {
                            viewModel.nextPage()
                        }
                    }
                }) {
                    Text(viewModel.isLastPage ? "Get Started" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Skip button
                if !viewModel.isLastPage {
                    Button("Skip") {
                        viewModel.completeOnboarding()
                        hasCompletedOnboarding = true
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer().frame(height: 20)
            }
        }
    }
}
