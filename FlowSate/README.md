# FlowState - Minimal Journal App

A clean, minimal journaling app inspired by MacroFactor's design philosophy.

## Design Principles

- **Data-First**: Numbers and stats are prominent
- **Clean & Minimal**: White backgrounds, subtle grays, strategic use of color
- **Readable Typography**: System fonts with clear hierarchy
- **Generous Spacing**: Breathing room between elements
- **Subtle Interactions**: Minimal shadows and decorations

## Features

### ✅ Implemented

- **Daily Journaling**: Write entries with auto-word count
- **Photo Attachments**: Add up to 10 photos per entry
- **Mood Tracking**: Select mood for each entry
- **Weekly Overview**: Bar chart showing journaling frequency
- **Entry Library**: Browse all entries organized by month
- **Search**: Find entries by content
- **Statistics**: Track words written, days journaled, averages

### 🚧 Coming Soon

- Grammar & spell check (Writing Assistant)
- Sunday weekly review with mood insights
- Daily reminders/notifications
- Streak tracking
- Export entries
- iCloud sync
- Dark mode optimizations

## Tech Stack

- **SwiftUI**: Modern declarative UI
- **SwiftData**: Local data persistence
- **Swift Charts**: Data visualization
- **PhotosUI**: Photo picker integration

## Project Structure

```
FlowSate/
├── FlowSateApp.swift          # App entry point
├── JournalEntry.swift         # Data model (Item.swift)
├── HomeView.swift             # Main dashboard
├── JournalEditorView.swift    # Entry editing screen
├── WeeklyOverviewView.swift   # Weekly stats & charts
└── EntryLibraryView.swift     # All entries browser
```

## Design Inspiration

This app follows MacroFactor's design approach:
- Minimal color palette (mostly grayscale)
- Bold, rounded numbers for data
- Inset grouped list style
- Clean section headers
- Simple, functional UI elements

## Running the App

1. Open in Xcode 15+
2. Select a simulator (iPhone 15 Pro recommended)
3. Press `Cmd + R` to build and run
4. Create your first journal entry!

## Next Steps for App Store

1. **Add App Icon** - Design a 1024x1024px icon
2. **Implement Writing Assistant** - Grammar/spell check API
3. **Add Notifications** - Daily reminders
4. **Testing** - Test on multiple devices and iOS versions
5. **Privacy Policy** - Required for App Store
6. **Screenshots** - Create for all required device sizes
7. **App Store Listing** - Write compelling description
