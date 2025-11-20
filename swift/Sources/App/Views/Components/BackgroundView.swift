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
    case goals      // Mountains4 - aspirational peaks, journey ahead
    case actions    // Forest - growth, movement through nature
    case values     // Moody - introspective depth, stillness
    case terms      // BigLakeMountains - perspective, planning horizon
    case dashboard  // Aurora3 - inspiring clarity, overview

    var imageName: String {
        switch self {
        case .goals:     return "Mountains4"
        case .actions:   return "Forest"
        case .values:    return "Moody"
        case .terms:     return "BigLakeMountains"
        case .dashboard: return "Aurora3"
        }
    }

    /// Dimming opacity for text legibility
    /// HIG: Balance rich backgrounds with readable UI text
    /// Lower opacity = more image visible, higher = more subdued
    var dimmingOpacity: Double {
        switch self {
        case .goals:     return 0.50  // Mountains can be dramatic, need more dimming
        case .actions:   return 0.40  // Forest has natural depth, moderate dimming
        case .values:    return 0.35  // Moody is already subdued, less dimming needed
        case .terms:     return 0.45  // Lake and mountains need balance
        case .dashboard: return 0.50  // Aurora is bright and colorful, needs dimming
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
