import Models
import SwiftUI

public struct PersonalValuesRowView: View {
    let value: PersonalValueData

    public init(value: PersonalValueData) {
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(value.title)
                    .font(.headline)

                Spacer()

                // Using BadgeView for consistent badge styling across app
                BadgeView(
                    badge: Badge(
                        text: "\(value.priority)",
                        color: .secondary
                    ))
            }

            if let description = value.detailedDescription {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Life domain as badge for visual distinction
            if let domain = value.lifeDomain {
                BadgeView(
                    badge: Badge(
                        text: domain,
                        color: .purple.opacity(0.8)
                    )
                )
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
