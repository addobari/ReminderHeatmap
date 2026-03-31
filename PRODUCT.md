# Reminder Heatmap — Product Overview

**Version:** 1.0  
**Platform:** macOS 14+ (Sonoma)  
**Last updated:** March 2026

---

## What is it?

Reminder Heatmap is a macOS desktop widget and companion app that turns your completed Apple Reminders into a GitHub-style contribution heatmap. At a glance, you see how productive you've been — no app required.

---

## The problem with Apple's Reminders widget

Apple's built-in Reminders widget shows your **upcoming** tasks — what you still need to do. It tells you nothing about what you've already accomplished.

| | Apple Reminders Widget | Reminder Heatmap |
|---|---|---|
| **Shows** | Pending tasks | Completed tasks |
| **Time range** | Today / upcoming | Last 3 months (widget), full year (app) |
| **Visual** | Text list | GitHub-style heatmap grid |
| **Insight** | "Here's what's left" | "Here's what I've done" |
| **Motivation** | Anxiety (growing todo list) | Accountability (visible streaks) |
| **Recurring habits** | No tracking | Dedicated tracker view per habit |
| **History** | None | Full year with day-by-day drill-down |
| **Interaction needed** | Must open Reminders app | Passive — just glance at desktop |

**The core gap:** Apple tells you what's undone. Reminder Heatmap tells you what's done.

---

## Who is this for?

People who use Apple Reminders as their daily task system and want a passive accountability signal on their desktop — without opening any app.

**What they need:** Install once, see the heatmap, never think about it again.

**What breaks trust:** Opening the widget and seeing stale or empty data with no explanation.

---

## Features

### Desktop Widget (medium size)

A two-column layout:

- **Left:** "REMINDERS" label + large green number showing completions this week
- **Right:** 13-week heatmap grid (last 3 months) with month labels, day labels (Mon/Wed/Fri), and color-coded cells
- **Footer:** Color legend (Less → More + Future indicator) and "Last 3 months" timestamp
- **Future cells:** Hollow bordered squares showing days that haven't happened yet
- **Tap:** Opens the companion app

The widget fetches directly from EventKit — no dependency on the app running. Refreshes every 30 minutes via WidgetKit.

### Companion App — Heatmap Tab

The main screen, dark-themed by default with light/dark/system mode support:

1. **Stat cards** — Streak (consecutive days with ≥1 completion), This Week (Mon–today), Today
2. **Today section** — Every completion from today with colored list dots, reminder names, list names, and timestamps
3. **Full-year heatmap** — Jan 1 → Dec 31 with year switcher (‹ 2025 · 2026 ›), month labels, day labels, future cells, and out-of-year padding handled
4. **Year stats** — Best day, Active days, Daily average (scoped to selected year, past days only)
5. **Day drill-down** — Tap any cell → see all completions grouped by list with timestamps

### Companion App — Trackers Tab

For recurring reminders (detected automatically via `EKReminder.recurrenceRules`):

- Each recurring task gets its own card with a full 30-day heatmap grid
- Card header shows task name, list color dot, and total completion count
- Tap any cell → inline day detail expands below the grid showing completion times
- Same GitHub color scale as the main heatmap

### Tracker Widget (medium size)

A separate widget showing recurring reminders as compact rows with 30-day mini strips and completion counts.

---

## Color Scale

Matches GitHub's contribution graph exactly, adapting to light and dark mode:

| Completions | Dark Mode | Light Mode |
|---|---|---|
| 0 | `white @ 9%` | `#ebedf0` |
| 1–2 | `#0e4429` | `#9be9a8` |
| 3–4 | `#006d32` | `#40c463` |
| 5–6 | `#26a641` | `#30a14e` |
| 7+ | `#39d353` | `#216e39` |

---

## Display States

The widget handles five states — no state shows a blank view:

| State | Trigger | Display |
|---|---|---|
| No permission | EventKit auth denied | "Open app to enable Reminders access" |
| Empty | Auth OK, zero completions | Empty grid + "Complete your first reminder to get started" |
| Loaded | Normal | Full heatmap |
| Stale | Last refresh > 2 hours | Same as loaded, "Last 3 months" text turns amber |
| Error | EventKit threw or auth revoked | "Reminders access removed. Open app to reconnect." |

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  macOS System                    │
│                                                  │
│  ┌──────────────┐         ┌───────────────────┐ │
│  │  Companion   │         │  Widget Extension │ │
│  │     App      │         │  (WidgetKit)      │ │
│  │              │         │                   │ │
│  │ ContentView  │         │ HeatmapWidgetView │ │
│  │ TrackersView │         │ TrackerWidgetView │ │
│  │ DayDetail    │         │                   │ │
│  └──────┬───────┘         └────────┬──────────┘ │
│         │                          │             │
│         │    ┌──────────────┐      │             │
│         └───►│   Shared     │◄─────┘             │
│              │              │                    │
│              │ HeatmapData  │──► EventKit (read) │
│              │ HeatmapTheme │                    │
│              │ Models       │                    │
│              └──────────────┘                    │
└─────────────────────────────────────────────────┘
```

- **Three targets:** App, Widget Extension, Shared module
- **No App Groups.** No shared UserDefaults. Widget is fully self-sufficient.
- **EventKit only.** Read-only access to completed reminders. No data leaves the Mac.
- **No server.** No accounts. No telemetry. No network calls.

---

## Data Flow

```
Widget Timeline Provider
  → EventKit.fetchCompletedReminders(last 91 days)
  → Group by calendar day (local timezone)
  → Calculate week count
  → Render two-column heatmap grid + legend
  → Refresh every 30 minutes
```

```
Companion App
  → EventKit.fetchYearData(year) for grid
  → EventKit.fetchDays(last: 90) for rolling stats
  → EventKit.fetchTrackerData(last: 30) for recurring
  → Refresh on app activation
```

---

## Key Decisions

| Decision | Rationale |
|---|---|
| Widget fetches directly from EventKit | No dependency on app running. Install once, works forever. |
| No App Groups | Simpler architecture. Widget doesn't need the app's state. |
| Rolling 90-day window for stats | Streak and week count work correctly across year boundaries. |
| Tracker ID = calendarIdentifier + title | Prevents same-named reminders in different lists from merging. |
| GitHub-exact color scale | Familiar visual language. Users already know what green squares mean. |
| Midnight cutoff for "missed today" | Never marks today as missed until the day is over. |
| System/Light/Dark mode picker | Respects user preference with explicit appearance resolution. |

---

## Privacy

- **Read-only** access to Apple Reminders via EventKit
- **No data leaves the Mac** — everything is processed locally
- **No analytics, telemetry, or tracking**
- **No accounts or sign-in**
- **No network requests**
- App Sandbox enabled

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Reminders app with at least one completed reminder
- Reminders access permission (prompted on first launch)

---

## Distribution

- Open source on [GitHub](https://github.com/addobari/ReminderHeatmap)
- Direct download via GitHub Releases (.zip)
- Not notarized — users right-click → Open on first launch
- MIT License
