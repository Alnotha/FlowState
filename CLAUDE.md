# CLAUDE.md

## Project Overview

FlowState is a minimal iOS journaling app built with SwiftUI and SwiftData. Design inspired by MacroFactor's clean, data-first approach with emphasis on statistics, weekly tracking, and readable typography.

**Author:** Alyan Tharani | **Created:** January 2026

## Tech Stack

- **SwiftUI** - Declarative UI (iOS 17+)
- **SwiftData** - Local persistence with `@Model` macro
- **Swift Charts** - Weekly activity bar charts
- **PhotosUI** - Native photo picker
- **Xcode 15+** required

## Project Structure

```
sarajevo/
├── .claude/settings.local.json     # Claude permissions (xcodebuild, simctl, gh)
├── .context/                       # Project context (todos.md, notes.md)
├── CLAUDE.md                       # This file
├── FlowSate/                       # Main app source (1,019 LOC)
│   ├── FlowSateApp.swift          # App entry, ModelContainer setup
│   ├── Item.swift                 # JournalEntry @Model (naming mismatch)
│   ├── ContentView.swift          # Deprecated - delegates to HomeView
│   ├── HomeView.swift             # Dashboard + nested components (~300 lines)
│   ├── JournalEditorView.swift    # Entry editor + photos/mood (~240 lines)
│   ├── WeeklyOverviewView.swift   # Stats, charts, achievements (~225 lines)
│   ├── EntryLibraryView.swift     # Searchable browser (~165 lines)
│   ├── README.md                  # Design docs
│   └── Assets.xcassets/           # Icons (placeholder) and colors
├── FlowSate.xcodeproj/            # Xcode configuration
├── FlowSateTests/                 # Unit tests (Swift Testing - stubs)
└── FlowSateUITests/               # UI tests (XCTest - stubs)
```

## Data Model

**JournalEntry** (in `Item.swift`):

```swift
@Model
final class JournalEntry {
    var id: UUID                   // Auto-generated
    var date: Date                 // Entry timestamp
    var content: String            // Journal text
    var mood: String?              // "happy", "calm", "sad", "frustrated", "thoughtful"
    var photoData: [Data]?         // Up to 10 photos as binary
    var wordCount: Int             // Auto-calculated

    // Computed
    var formattedDate: String      // Medium format (e.g., "Jan 2, 2026")
    var isToday: Bool              // Calendar.current.isDateInToday()

    // Methods
    func updateWordCount()         // Recalculates from content
}
```

**SwiftData Config** (FlowSateApp.swift):
- Schema: `[JournalEntry.self]`
- Storage: Persistent (not in-memory)
- Container injected via `.modelContainer()` modifier

## View Architecture

```
FlowSateApp
└── HomeView (NavigationStack root)
    ├── WeeklyStreakCard           # Days journaled this week
    ├── TodayEntryCard             # Today's entry preview
    │   └── JournalEditorView      # Modal sheet
    ├── EntryRowCard               # Recent entries list
    │   └── JournalEditorView      # Navigation push
    ├── "See All" link
    │   └── EntryLibraryView       # Full browser
    └── Chart toolbar icon
        └── WeeklyOverviewView     # Statistics dashboard
```

**Nested Components per View:**
- **HomeView**: WeeklyStreakCard, TodayEntryCard, EmptyEntryCard, EntryRowCard
- **JournalEditorView**: StatItem
- **WeeklyOverviewView**: StatCard, InsightCard
- **EntryLibraryView**: EntryLibraryRow, EmptyLibraryView

## SwiftUI Patterns

| Pattern | Usage |
|---------|-------|
| `@Query(sort:order:)` | Reactive data fetching |
| `@Bindable` | Two-way binding to entry model |
| `@Environment(\.modelContext)` | Create/delete operations |
| `@Environment(\.dismiss)` | Programmatic dismissal |
| `@State` | Local view state (searchText, showingEditor) |
| `@FocusState` | Keyboard management |
| `.sheet()` | Modal editor presentation |
| `NavigationLink` | Page navigation |
| Computed properties | Derived data (todayEntry, filteredEntries, weeklyStreak) |

## Build & Run

```bash
# Open in Xcode
open FlowSate.xcodeproj

# Command line build
xcodebuild -project FlowSate.xcodeproj -scheme FlowSate \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run tests
xcodebuild -project FlowSate.xcodeproj -scheme FlowSate \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test
```

## Features

### Implemented
- **Daily Journaling** - TextEditor with auto word/character count, auto-focus on new entries
- **Mood Tracking** - 5 options with emoji display (Happy 😊, Calm 😌, Sad 😔, Frustrated 😤, Thoughtful 🤔)
- **Photo Attachments** - Up to 10 photos per entry via PhotosUI, stored as binary Data
- **Weekly Dashboard** - Bar chart, days journaled (X/7), total words
- **Achievements** - "Consistency Champion" (5+ days), "Prolific Writer" (1000+ words)
- **Entry Library** - Full-text search, monthly grouping, swipe-to-delete
- **Home Dashboard** - Time-based greeting, streak card, recent entries

### Planned
- Writing assistant (grammar/spell check API)
- Daily reminders/notifications
- Streak tracking improvements
- Export (PDF, CSV)
- iCloud sync
- Dark mode optimizations
- App icon design

## Design System

### Colors
- **Background**: `.systemGroupedBackground` (light), `.systemBackground` (cards)
- **Accents**: `.blue` (primary), `.green` (success/streak), `.orange` (insights)
- **Text**: `.primary`, `.secondary`, `.tertiary`

### Typography
- **Page headers**: `.largeTitle.bold`
- **Section headers**: `.title2.semibold`
- **Stats**: `.system(size: 24-36, weight: .bold, design: .rounded)` - bold rounded numbers
- **Labels**: `.caption`, `.subheadline`

### Cards
- **Corner radius**: 16px (main), 12px (rows), 8px (thumbnails)
- **Shadow**: `color: .black.opacity(0.05), radius: 8, y: 2`
- **Spacing**: 24pt (sections), 16pt (cards), 12pt (internals)

### Icons
SF Symbols with `.gradient` modifier:
- `pencil.circle.fill` - editing
- `chart.bar.fill` - statistics
- `calendar.badge.checkmark` - streak
- `flame.fill`, `star.fill` - achievements

## Code Conventions

1. **File naming**: `[Feature]View.swift`
2. **Component nesting**: Helper views nested inside parent file (not separate)
3. **MARK pragmas**: `// MARK: - Supporting Views` for organization
4. **Date logic**: `Calendar.current` for all date operations
5. **Search**: `localizedCaseInsensitiveContains()` for user-friendly matching
6. **Photo handling**: Async `loadTransferable()` with context menu deletion

## Known Issues

| Issue | Details |
|-------|---------|
| Project name typo | Folder "FlowSate" vs intended "FlowState" |
| File naming mismatch | `Item.swift` contains `JournalEntry` class |
| Deprecated file | `ContentView.swift` still exists, delegates to HomeView |
| Photo storage | Raw Data without compression optimization |
| Test coverage | 0% - all tests are placeholder stubs |
| Asset placeholders | AppIcon and AccentColor defined but not populated |
| No theme file | Colors hardcoded throughout views |

## Quick Reference

| File | Lines | Purpose |
|------|-------|---------|
| HomeView.swift | ~300 | Dashboard, greeting, streak, recent entries |
| JournalEditorView.swift | ~240 | Text editor, mood selector, photo picker |
| WeeklyOverviewView.swift | ~225 | Stats cards, bar chart, achievements |
| EntryLibraryView.swift | ~165 | Search, monthly groups, entry list |
| Item.swift | ~47 | JournalEntry data model |
| FlowSateApp.swift | ~32 | App entry, ModelContainer |
