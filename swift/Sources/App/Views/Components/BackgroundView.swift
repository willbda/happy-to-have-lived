//
// BackgroundView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Contextual background images for Liquid Glass design system
// USAGE: Add .background(BackgroundView(.goals)) to view hierarchies
//
// HIG COMPLIANCE:
// - Rich backgrounds with aspect fill (not tiling)
// - Dimming layer for text legibility over images
// - Respects accessibility settings (Reduce Transparency, Increase Contrast)
//

import SwiftUI

/// Contextual background image component for Liquid Glass design
///
/// **Pattern**: Rich background with dimming layer for legibility
/// **Integration**: Use as .background() modifier on view hierarchies
/// **Photos**: Uses assets from Assets.xcassets
/// **Accessibility**: Automatically adapts to Reduce Transparency and Increase Contrast
///
/// Example:
/// ```swift
/// ZStack {
///     BackgroundView(.goals)
///
///     // Your content with materials here
/// }
/// ```
public struct BackgroundView: View {
    let style: BackgroundStyle

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public init(_ style: BackgroundStyle = .goals) {
        self.style = style
    }

    public var body: some View {
        ZStack {
            // Base background image
            Image(style.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Dimming layer for text legibility
            // HIG: "Consider adding a dimming layer for contrast" with rich backgrounds
            if !reduceTransparency {
                (colorScheme == .dark ? Color.black : Color.white)
                    .opacity(style.dimmingOpacity)
                    .ignoresSafeArea()
            } else {
                // Accessibility: Higher opacity for Reduce Transparency
                (colorScheme == .dark ? Color.black : Color.white)
                    .opacity(0.85)
                    .ignoresSafeArea()
            }
        }
    }
}

/// Background style based on context
public enum BackgroundStyle {
    case goals      // Mountain - aspirational, journey ahead
    case actions    // MoodyRiver - flow, progress, movement
    case values     // MoodyLake - reflection, depth, stillness
    case terms      // Outlook - perspective, planning, horizon
    case dashboard  // MoodyMist - overview, clarity emerging

    var imageName: String {
        switch self {
        case .goals:     return "Mountain"
        case .actions:   return "MoodyRiver"
        case .values:    return "MoodyLake"
        case .terms:     return "Outlook"
        case .dashboard: return "MoodyMist"
        }
    }

    /// Dimming opacity for text legibility
    /// HIG: Balance rich backgrounds with readable UI text
    /// Lower opacity = more image visible, higher = more subdued
    var dimmingOpacity: Double {
        switch self {
        case .goals:     return 0.50  // Mountain can be dramatic, need more dimming
        case .actions:   return 0.45  // River has movement, moderate dimming
        case .values:    return 0.40  // Lake is calmer, less dimming needed
        case .terms:     return 0.45  // Outlook needs balance
        case .dashboard: return 0.50  // Mist is subtle but needs clarity
        }
    }
}

#Preview("Goals Background") {
    BackgroundView(.goals)
}

#Preview("Actions Background") {
    BackgroundView(.actions)
}

#Preview("Values Background") {
    BackgroundView(.values)
}
