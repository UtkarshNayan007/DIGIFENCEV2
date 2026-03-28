//
//  DesignSystem.swift
//  DIGIFENCEV1
//
//  Unified design system — single source of truth for all UI tokens and reusable components.
//

import SwiftUI

// MARK: - Design Tokens

enum DFSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum DFCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let pill: CGFloat = 100
}

// MARK: - Brand Colors

extension Color {
    static let dfAccent = Color.cyan
    static let dfAccentGradientStart = Color.cyan
    static let dfAccentGradientEnd = Color.blue
    static let dfSuccess = Color.green
    static let dfWarning = Color.orange
    static let dfError = Color.red
}

// MARK: - Gradients

struct DFGradients {
    static let accent = LinearGradient(
        colors: [.dfAccentGradientStart, .dfAccentGradientEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let accentHorizontal = LinearGradient(
        colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing
    )
    static let success = LinearGradient(
        colors: [.green, .mint], startPoint: .leading, endPoint: .trailing
    )
    static let subtle = LinearGradient(
        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Button Styles

struct DFScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DFCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Primary Button

struct DFPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var colors: [Color] = [.cyan, .blue]
    var height: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            action()
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                isDisabled
                    ? AnyShapeStyle(Color(.systemGray3))
                    : AnyShapeStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            )
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
            .shadow(color: isDisabled ? .clear : colors.first!.opacity(0.25), radius: 10, y: 5)
        }
        .disabled(isLoading || isDisabled)
        .buttonStyle(DFScaleButtonStyle())
    }
}


// MARK: - Secondary Button

struct DFSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var foregroundColor: Color = .primary
    var height: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    if let icon {
                        Image(systemName: icon).font(.system(size: 16, weight: .medium))
                    }
                    Text(title).font(.system(size: 15, weight: .medium))
                }
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                    .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
            )
        }
        .disabled(isLoading)
        .buttonStyle(DFScaleButtonStyle())
    }
}

// MARK: - Destructive Button

struct DFDestructiveButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.warning()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.red)
                } else {
                    if let icon {
                        Image(systemName: icon).font(.system(size: 15, weight: .medium))
                    }
                    Text(title).font(.system(size: 15, weight: .medium))
                }
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        }
        .disabled(isLoading)
        .buttonStyle(DFScaleButtonStyle())
    }
}

// MARK: - Text Fields

struct DFTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? .dfAccent : .secondary)
                .frame(width: 22)
                .animation(.easeInOut(duration: 0.2), value: isFocused)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isFocused)
        }
        .padding(.horizontal, DFSpacing.lg)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                .stroke(isFocused ? Color.dfAccent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

struct DFSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var showPassword = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? .dfAccent : .secondary)
                .frame(width: 22)
                .animation(.easeInOut(duration: 0.2), value: isFocused)

            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16))
            .focused($isFocused)

            Button {
                HapticManager.shared.light()
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, DFSpacing.lg)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous)
                .stroke(isFocused ? Color.dfAccent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

// MARK: - Status Badge

struct DFStatusBadge: View {
    let text: String
    var color: Color = .dfAccent
    var size: DFBadgeSize = .medium

    enum DFBadgeSize {
        case small, medium, large
        var fontSize: CGFloat {
            switch self { case .small: return 9; case .medium: return 11; case .large: return 13 }
        }
        var hPad: CGFloat {
            switch self { case .small: return 6; case .medium: return 10; case .large: return 12 }
        }
        var vPad: CGFloat {
            switch self { case .small: return 3; case .medium: return 5; case .large: return 6 }
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: size.fontSize, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, size.hPad)
            .padding(.vertical, size.vPad)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Section Header

struct DFSectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .secondary
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        HStack(spacing: DFSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.dfAccent)
                }
            }
        }
        .padding(.top, DFSpacing.md)
    }
}

// MARK: - Card

struct DFCard<Content: View>: View {
    var padding: CGFloat = DFSpacing.lg
    var cornerRadius: CGFloat = DFCornerRadius.xl
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

// MARK: - Empty State

struct DFEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: DFSpacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.dfAccent.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.dfAccent)
            }
            .scaleEffect(appeared ? 1.0 : 0.6)

            VStack(spacing: DFSpacing.sm) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DFSpacing.xxl)
                }
            }
            .opacity(appeared ? 1 : 0)

            if let actionTitle, let action {
                DFPrimaryButton(title: actionTitle, action: action)
                    .padding(.horizontal, DFSpacing.xxxl)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Icon Badge

struct DFIconBadge: View {
    let icon: String
    var color: Color = .dfAccent
    var size: CGFloat = 44
    var iconSize: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Progress Bar

struct DFProgressBar: View {
    let progress: Double
    var height: CGFloat = 8
    var foregroundColors: [Color] = [.cyan, .blue]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(.systemGray5))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(LinearGradient(colors: foregroundColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(1.0, max(0, progress)), height: height)
                    .animation(.spring(response: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Divider

struct DFDivider: View {
    var leadingInset: CGFloat = 0
    var body: some View {
        Divider().padding(.leading, leadingInset)
    }
}

// MARK: - Info Row

struct DFInfoRow: View {
    let icon: String
    var iconColor: Color = .secondary
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 26)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, DFSpacing.lg)
        .padding(.vertical, 11)
    }
}

// MARK: - Map Pin

struct DFMapPin: View {
    var color: Color = .dfAccent
    var size: CGFloat = 44
    @State private var appeared = false
    @State private var bouncing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
                .scaleEffect(bouncing ? 1.15 : 1.0)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: size * 0.7))
                .foregroundColor(color)
        }
        .offset(y: appeared ? 0 : -20)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3)) { bouncing = true }
        }
    }
}

// MARK: - Floating Action Button

struct DFFloatingActionButton: View {
    let icon: String
    var colors: [Color] = [.cyan, .blue]
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
                .shadow(color: colors.first!.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(DFScaleButtonStyle())
    }
}

// MARK: - Animated Logo

struct DFAnimatedLogo: View {
    var size: CGFloat = 100
    var cornerRadius: CGFloat = 24
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: 25)
                .opacity(opacity)
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: Color.cyan.opacity(0.3), radius: 20, y: 8)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) {
                scale = 1.0; opacity = 1.0
            }
        }
    }
}

// MARK: - Entrance Animation

struct DFEntranceAnimation: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.8)
                .delay(baseDelay + Double(index) * 0.04),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

extension View {
    func entranceAnimation(index: Int = 0, baseDelay: Double = 0) -> some View {
        modifier(DFEntranceAnimation(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Shimmer

struct DFShimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.25), .white.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(DFShimmer()) }
}

// MARK: - Blur Background

struct DFBlurBackground: View {
    var style: UIBlurEffect.Style = .systemMaterial
    var body: some View {
        VisualEffectBlur(blurStyle: style).ignoresSafeArea()
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: blurStyle)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = UIBlurEffect(style: blurStyle) }
}

// MARK: - Stat Card

struct DFStatCard: View {
    let value: String
    let label: String
    var icon: String? = nil
    var color: Color = .dfAccent
    @State private var appeared = false

    var body: some View {
        VStack(spacing: DFSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DFSpacing.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Floating Search Bar

struct DFFloatingSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DFSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? .dfAccent : .secondary)
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .focused($isFocused)
            if !text.isEmpty {
                Button { HapticManager.shared.light(); text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DFSpacing.lg)
        .frame(height: 48)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DFCornerRadius.lg, style: .continuous)
                .stroke(isFocused ? Color.dfAccent.opacity(0.4) : .clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Glass Card

struct DFGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = DFCornerRadius.xl
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Pulse Modifier

struct DFPulse: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulse() -> some View { modifier(DFPulse()) }
}


// MARK: - Safe Double → Int Conversion

/// Safely converts a Double to Int, clamping to Int range and handling NaN/infinity.
func safeIntFromDouble(_ value: Double) -> Int {
    guard value.isFinite else { return 0 }
    if value >= Double(Int.max) { return Int.max }
    if value <= Double(Int.min) { return Int.min }
    return Int(value)
}
