//
//  OnboardingViewModel.swift
//  DIGIFENCEV1
//
//  Manages onboarding page state and biometric enrollment guidance.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    @Published var currentPage = 0
    @Published var hasCompletedOnboarding = false
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "mappin.and.ellipse",
            title: "Location-Locked Passes",
            description: "Your event pass activates automatically when you arrive at the venue. No QR codes, no scanning — just walk in."
        ),
        OnboardingPage(
            icon: "faceid",
            title: "Biometric Security",
            description: "Your pass is bound to your biometrics. Face ID or Touch ID ensures only you can use your ticket."
        ),
        OnboardingPage(
            icon: "AppLogo",
            title: "Tamper-Proof",
            description: "Cryptographic signatures verified server-side. No fake passes, no GPS spoofing, no sharing."
        ),
        OnboardingPage(
            icon: "bell.badge",
            title: "Smart Notifications",
            description: "Get alerted if you leave the event zone. Return within 3 minutes to keep your pass active."
        ),
    ]
    
    var isLastPage: Bool {
        currentPage == pages.count - 1
    }
    
    func nextPage() {
        if isLastPage {
            completeOnboarding()
        } else {
            currentPage += 1
        }
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "DigiFence_OnboardingComplete")
        hasCompletedOnboarding = true
    }
    
    func checkOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "DigiFence_OnboardingComplete")
    }
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}
