import SwiftUI

struct EmptyStateView: View {
    /// A label/handler pair for the optional call-to-action button.
    /// Grouping them in one struct makes it impossible to pass a label
    /// without a handler (or vice versa) and silently lose the button.
    struct Action {
        let label: String
        let handler: () -> Void

        init(label: String, handler: @escaping () -> Void) {
            self.label = label
            self.handler = handler
        }
    }

    let icon: String
    let title: String
    let subtitle: String?
    let action: Action?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        action: Action? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.neonBlue, .neonPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            if let action = action {
                Button(action: action.handler) {
                    Text(action.label)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.neonBlue, .neonPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "Nothing here",
        subtitle: "Pull to refresh or check back later.",
        action: .init(label: "Retry") {}
    )
}
