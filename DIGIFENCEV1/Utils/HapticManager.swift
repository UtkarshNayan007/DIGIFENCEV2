//
//  HapticManager.swift
//  DIGIFENCEV1
//
//  Centralized haptic feedback manager for Apple-native feel.
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()
    private init() {}
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    func light() { impactLight.impactOccurred() }
    func medium() { impactMedium.impactOccurred() }
    func heavy() { impactHeavy.impactOccurred() }
    func soft() { impactSoft.impactOccurred() }
    func selection() { selectionGenerator.selectionChanged() }
    func success() { notificationGenerator.notificationOccurred(.success) }
    func warning() { notificationGenerator.notificationOccurred(.warning) }
    func error() { notificationGenerator.notificationOccurred(.error) }
    
    func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
}
