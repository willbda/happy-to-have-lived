//
// HomeView.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Main dashboard view showing active goals and recent actions
// PATTERN: Hero image + parallax scroll (inspired by Calm app and Apple Music)
//
// LAYOUT:
// 1. Hero image (upper ~35%) with parallax fade effect
// 2. Greeting overlay (3 lines, white text with shadow)
// 3. Active goals horizontal carousel
// 4. Quick action button (Log Action)
// 5. Recent actions list (color-coded by goal)
//
// REFERENCES:
// - Calm app: Hero image with fade-on-scroll
// - Apple Music: Gradient overlays for readability
// - Apple Health: Card-based content sections
//

import SwiftUI

public struct HomeView: View {
    // MARK: - State

    @State private var scrollOffset: CGFloat = 0

    // MARK: - Constants

    private let heroHeight: CGFloat = 300

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hero image with parallax effect
                    GeometryReader { geometry in
                        let minY = geometry.frame(in: .global).minY
                        let imageHeight = max(0, heroHeight + (minY > 0 ? minY : 0))
                        let opacity = max(0, 1 - (minY / -150))

                        Image("Mountains4")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                            .opacity(opacity)
                            .offset(y: minY > 0 ? -minY : 0)

                        // Gradient overlay for readability
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: imageHeight)
                    }
                    .frame(height: heroHeight)

                    // Greeting overlay (on hero image)
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()

                        Text("Good morning")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 2)

                        Text("Here's what's")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)

                        Text("happening")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: heroHeight)
                }

                // Content sections (scroll over hero)
                VStack(spacing: 24) {
                    // Active Goals Section
                    activeGoalsSection

                    // Quick Action Button
                    quickActionButton

                    // Recent Actions Section
                    recentActionsSection
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .offset(y: -16) // Overlap hero slightly
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    // Menu button (Settings, Export, etc.)
                    Menu {
                        Button(action: {}) {
                            Label("Settings", systemImage: "gear")
                        }
                        Button(action: {}) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        Button(action: {}) {
                            Label("Review Duplicates", systemImage: "doc.on.doc")
                        }
                        Button(action: {}) {
                            Label("Archives", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Goals")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {}) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Horizontal carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Placeholder goal cards
                    ForEach(0..<5) { index in
                        goalCardPlaceholder(index: index)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var quickActionButton: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                Text("Log an Action")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    private var recentActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Actions")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {}) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Action list
            VStack(spacing: 0) {
                ForEach(0..<7) { index in
                    actionRowPlaceholder(index: index)

                    if index < 6 {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .background(Color(.cyan))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Placeholder Components

    private func goalCardPlaceholder(index: Int) -> some View {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        let titles = ["Marathon Training", "Read 12 Books", "Learn Swift", "Weekly Reflection", "Health Goals"]
        let progress: [Double] = [0.65, 0.42, 0.88, 0.20, 0.55]

        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress[index])
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress[index] * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            Spacer()

            // Goal info
            VStack(alignment: .leading, spacing: 4) {
                Text(titles[index])
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("Target: Dec 31")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
        .frame(width: 160, height: 200)
        .background(
            LinearGradient(
                colors: [colors[index].opacity(0.8), colors[index]],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func actionRowPlaceholder(index: Int) -> some View {
        let icons = ["figure.run", "book.fill", "dumbbell.fill", "pencil", "heart.fill", "bicycle", "fork.knife"]
        let titles = ["Morning run", "Read chapter 3", "Weight training", "Journal entry", "Meditation", "Bike commute", "Meal prep"]
        let measurements = ["5 km, 45 min", "30 min", "1 hour", "15 min", "20 min", "8 km", "2 hours"]
        let goalLinks = ["Marathon Training", "Read 12 Books", "Health Goals", "Weekly Reflection", "Mindfulness", "Health Goals", "Nutrition"]
        let borderColors: [Color] = [.blue, .green, .orange, .purple, .pink, .orange, .red]

        return HStack(spacing: 12) {
            // Icon
            Image(systemName: icons[index])
                .font(.title3)
                .foregroundStyle(borderColors[index])
                .frame(width: 40, height: 40)
                .background(borderColors[index].opacity(0.1))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(titles[index])
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(measurements[index])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Goal badge
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text(goalLinks[index])
                        .font(.caption)
                }
                .foregroundStyle(borderColors[index])
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(borderColors[index].opacity(0.1))
                .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(borderColors[index].opacity(0.05))
        .overlay(
            Rectangle()
                .fill(borderColors[index])
                .frame(width: 3),
            alignment: .leading
        )
    }
}

// MARK: - Preview

#Preview("Home - Morning") {
    HomeView()
}

#Preview("Home - With Tab Bar") {
    TabView {
        HomeView()
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

        Text("Plans")
            .tabItem {
                Label("Plans", systemImage: "list.bullet.clipboard")
            }

        Text("Search")
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
    }
}
