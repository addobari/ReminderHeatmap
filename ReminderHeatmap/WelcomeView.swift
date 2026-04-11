import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("square.grid.3x3.fill", "Welcome to Plotted", "Visualize your completed reminders as a GitHub-style heatmap"),
        ("lock.open.fill", "Grant Access", "Plotted reads your completed reminders. Nothing leaves your Mac."),
        ("macwindow.on.rectangle", "Add a Widget", "Right-click your desktop → Edit Widgets → search Plotted"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button {
                    hasSeenWelcome = true
                    dismiss()
                } label: {
                    Text("Skip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            // Icon
            Image(systemName: pages[currentPage].icon)
                .font(.system(size: 56))
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                .frame(height: 72)
                .padding(.bottom, 24)

            // Title
            Text(pages[currentPage].title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Subtitle
            Text(pages[currentPage].subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.bottom, 32)

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage
                            ? HeatmapTheme.accentGreen(for: colorScheme)
                            : HeatmapTheme.emptyColor(for: colorScheme))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 20)

            // Button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage += 1
                    }
                } else {
                    hasSeenWelcome = true
                    dismiss()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HeatmapTheme.accentGreen(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .padding(32)
        .frame(width: 420, height: 400)
    }
}
