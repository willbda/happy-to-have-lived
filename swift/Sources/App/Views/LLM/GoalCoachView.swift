//
//  GoalCoachView.swift
//  ten-week-goal-app
//
//  Written by Claude Code on 2025-11-15
//
//  PURPOSE: Chat interface for AI goal coaching
//  PATTERN: Simple chat UI with scrolling messages and text input
//

import SwiftUI

/// Chat interface for AI goal coaching
@available(iOS 26.0, macOS 26.0, *)
public struct GoalCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = GoalCoachViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Thinking indicator
                        if viewModel.isThinking {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.last?.id) { _, _ in
                    // Auto-scroll to bottom on new message
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error message
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption)
                }
                .padding()
                .background(.orange.opacity(0.1))
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Ask about your goals...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }

                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.inputText.isEmpty ? .gray : .blue)
                }
                .disabled(viewModel.inputText.isEmpty || viewModel.isThinking)
            }
            .padding()
        }
        .navigationTitle("Goal Coach")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.restartConversation()
                    }
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .task {
            await viewModel.startConversation()
        }
    }
}

/// Message bubble for chat
@available(iOS 26.0, macOS 26.0, *)
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundStyle(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return .secondary.opacity(0.15)
        case .system:
            return .secondary.opacity(0.08)
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return .primary
        }
    }
}

#Preview("Goal Coach") {
    NavigationStack {
        GoalCoachView()
    }
}
