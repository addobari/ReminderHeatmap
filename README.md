# Reminder Heatmap

A macOS desktop widget that visualizes your completed Apple Reminders as a GitHub-style contribution heatmap. See how productive you've been — at a glance, right on your desktop.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Heatmap Widget** — GitHub-style contribution grid showing the last 3 months of completed reminders, right on your desktop
- **Companion App** — Full-year heatmap with year switcher, today's completions, streak tracking, and detailed stats
- **Trackers Tab** — Recurring reminders shown as individual 30-day heatmap cards
- **Tap any day** — See exactly what you completed and when
- **Fully local** — All data stays on your Mac. No accounts, no servers, no telemetry.

## Screenshots

| Widget | Companion App |
|--------|--------------|
| Two-column heatmap widget with weekly count | Full-year heatmap with stats and today's completions |

## Install

### Download

1. Go to [**Releases**](../../releases) and download the latest `.zip`
2. Unzip and drag **ReminderHeatmap.app** to your Applications folder
3. Open the app — it will ask for Reminders permission
4. Right-click your desktop → **Edit Widgets** → search "Reminder Heatmap" → add the widget

### Gatekeeper Notice

This app is not notarized with Apple. On first launch, macOS will block it. To open:

1. **Right-click** (or Control-click) the app → **Open**
2. Click **Open** in the dialog
3. Or go to **System Settings → Privacy & Security** → scroll down and click **Open Anyway**

You only need to do this once.

## Building from Source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ReminderHeatmap
xcodegen generate
xcodebuild -project ReminderHeatmap.xcodeproj -scheme ReminderHeatmap -configuration Release build
```

## How It Works

- Reads completed reminders via Apple's EventKit framework (read-only access)
- Widget refreshes every 30 minutes via WidgetKit
- No App Groups or shared storage — the widget fetches directly from EventKit
- Completions grouped by calendar day in your local timezone

## Architecture

```
ReminderHeatmap/          # macOS companion app
  ContentView.swift       # Heatmap tab — year grid, stats, today section
  TrackersView.swift      # Trackers tab — per-task 30-day heatmaps
  ReminderManager.swift   # Data management, year switching
  DayDetailView.swift     # Drill-down for a specific day

Shared/                   # Shared between app + widget
  HeatmapData.swift       # EventKit fetch, models, data processing
  HeatmapGridView.swift   # Reusable heatmap grid component

ReminderHeatmapWidget/    # WidgetKit extension
  HeatmapWidgetView.swift # Two-column widget layout
  TrackerWidgetView.swift  # Tracker widget layout
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Reminders app (with at least one completed reminder)

## License

MIT
