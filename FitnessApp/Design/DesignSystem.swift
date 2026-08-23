import SwiftUI

enum AppTheme {
    static let accent = Color.accentColor
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let cardRadius: CGFloat = 22
    static let pagePadding: CGFloat = 18

    static let muscleScale: [Color] = [
        Color.secondary.opacity(0.12),
        Color.blue.opacity(0.28),
        Color.blue.opacity(0.48),
        Color.blue.opacity(0.72),
        Color.blue
    ]
}

struct ContentCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.045), radius: 16, y: 7)
            )
    }
}

extension View {
    func contentCard() -> some View { modifier(ContentCardModifier()) }
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
    var tint: Color = .accentColor

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

