import SwiftUI
import UIKit

enum AppTheme {
    static let accent = Color.primary
    static let onAccent = Color(uiColor: .systemBackground)
    static let success = Color.primary
    static let warning = Color.primary
    static let danger = Color.red
    static let cardRadius: CGFloat = 22
    static let pagePadding: CGFloat = 18

    static let muscleScale: [Color] = [
        Color.secondary.opacity(0.10),
        Color.primary.opacity(0.24),
        Color.primary.opacity(0.42),
        Color.primary.opacity(0.66),
        Color.primary.opacity(0.92)
    ]
}

struct ContentCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.065) : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 18, y: 8)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.045), lineWidth: 0.75)
                    }
            )
    }
}

extension View {
    func contentCard() -> some View { modifier(ContentCardModifier()) }
}

struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WindowProbeView {
        let view = WindowProbeView()
        view.onWindowChange = { window in context.coordinator.install(on: window) }
        return view
    }

    func updateUIView(_ uiView: WindowProbeView, context: Context) {}

    static func dismantleUIView(_ uiView: WindowProbeView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTapWindow))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func install(on window: UIWindow?) {
            guard installedWindow !== window else { return }
            uninstall()
            guard let window else { return }
            window.addGestureRecognizer(recognizer)
            installedWindow = window
        }

        func uninstall() {
            installedWindow?.removeGestureRecognizer(recognizer)
            installedWindow = nil
        }

        @objc private func didTapWindow() {
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            KeyboardDismissalPolicy.shouldDismiss(for: touch.view)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    final class WindowProbeView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }
}

enum KeyboardDismissalPolicy {
    @MainActor
    static func shouldDismiss(for touchedView: UIView?) -> Bool {
        var candidate = touchedView
        while let view = candidate {
            if view is UITextField || view is UITextView || view is UIControl {
                return false
            }
            if view.accessibilityTraits.contains(.button) || view.accessibilityTraits.contains(.adjustable) {
                return false
            }
            candidate = view.superview
        }
        return true
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var action: String?
    var handler: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let action, let handler {
                Button(action, action: handler)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct MetricPill: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
