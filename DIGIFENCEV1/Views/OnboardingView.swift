//
//  OnboardingView.swift
//  DIGIFENCEV1
//
//  Clean, minimal onboarding with fluid page transitions.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $viewModel.currentPage) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: viewModel.currentPage) { HapticManager.shared.selection() }

                bottomControls
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: DFSpacing.xl) {
            // Page dots
            HStack(spacing: 10) {
                ForEach(0..<viewModel.pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == viewModel.currentPage ? Color.dfAccent : Color(.systemGray4))
                        .frame(width: i == viewModel.currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.currentPage)
                }
            }

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
            .padding(.horizontal, DFSpacing.xl)

            if !viewModel.isLastPage {
                Button("Skip") {
                    HapticManager.shared.light()
                    viewModel.completeOnboarding()
                    hasCompletedOnboarding = true
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            }

            Spacer().frame(height: DFSpacing.xl)
        }
    }
}

// MARK: - Onboarding Page

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(spacing: DFSpacing.xxxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.dfAccent.opacity(0.06))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(Color.dfAccent.opacity(0.1))
                    .frame(width: 140, height: 140)

                if page.icon == "AppLogo" {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .cyan.opacity(0.3), radius: 12, y: 6)
                } else {
                    Image(systemName: page.icon)
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(DFGradients.accent)
                }
            }
            .scaleEffect(appeared ? 1.0 : 0.4)
            .opacity(appeared ? 1.0 : 0)

            // Text
            VStack(spacing: DFSpacing.md) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, DFSpacing.xxl)
            }
            .opacity(appeared ? 1.0 : 0)
            .offset(y: appeared ? 0 : 16)

            Spacer()
            Spacer()
        }
        .onAppear {
            appeared = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) { appeared = true }
        }
    }
}
