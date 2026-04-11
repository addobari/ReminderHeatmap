import SwiftUI

// MARK: - Share Button

struct ShareHeatmapView: View {
    let yearDays: [HeatmapDay]
    let year: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            shareHeatmap()
        } label: {
            Label("Share Heatmap", systemImage: "square.and.arrow.up")
        }
    }

    @MainActor
    private func shareHeatmap() {
        let totalCompletions = yearDays.reduce(0) { $0 + $1.count }
        let shareView = HeatmapShareImage(
            yearDays: yearDays,
            year: year,
            totalCompletions: totalCompletions
        )

        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else { return }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(
            width: cgImage.width / 2,
            height: cgImage.height / 2
        ))

        guard let button = NSApp.keyWindow?.contentView?.hitTest(
            NSApp.keyWindow?.mouseLocationOutsideOfEventStream ?? .zero
        ) else {
            // Fallback: use pasteboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
            return
        }

        let picker = NSSharingServicePicker(items: [nsImage])
        picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

// MARK: - Rendered Share Image

private struct HeatmapShareImage: View {
    let yearDays: [HeatmapDay]
    let year: Int
    let totalCompletions: Int

    private let scheme: ColorScheme = .dark

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plotted")
                        .font(.title2.bold())
                    Text("\(year, format: .number.grouping(.never))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(totalCompletions) completions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(HeatmapTheme.accentGreen(for: scheme))
            }

            // Grid
            YearHeatmapGrid(days: yearDays, year: year)

            // Footer
            HStack {
                Spacer()
                Text("plotted.app")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .environment(\.colorScheme, scheme)
        .frame(width: 640)
    }
}
