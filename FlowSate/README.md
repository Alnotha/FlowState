# FlowState - Minimal Journal App

A clean, minimal journaling app inspired by MacroFactor's design philosophy.

## Design Principles

- **Data-First**: Numbers and stats are prominent
- **Clean & Minimal**: White backgrounds, subtle grays, strategic use of color
- **Readable Typography**: System fonts with clear hierarchy
- **Generous Spacing**: Breathing room between elements
- **Subtle Interactions**: Minimal shadows and decorations

## Features

### Core
- **Daily Journaling**: Write entries with auto-word count and character count
- **Photo Attachments**: Add up to 10 photos per entry with validation
- **Mood Tracking**: Select mood for each entry (Happy, Calm, Sad, Frustrated, Thoughtful)
- **Writing Assistant**: Real-time spell checking with tap-to-fix suggestions
- **Search**: Find entries by content or mood

### Analytics & Insights
- **Weekly Overview**: Bar chart showing journaling frequency with mood distribution
- **Weekly Review**: Sunday recap with mood breakdown, writing trends, and highlights
- **Streak Tracking**: Current streak, longest streak, and weekly dot visualization
- **Entry Library**: Browse all entries organized by month

### Productivity
- **Daily Reminders**: Configurable push notifications for journaling
- **Export Entries**: Export as text or JSON with share sheet
- **iCloud Sync**: Automatic sync via CloudKit (requires iCloud entitlement)
- **Dark Mode**: Full dark mode support with system/light/dark toggle

### Settings
- Notification scheduling with custom time
- Appearance mode (System/Light/Dark)
- Export all entries
- Privacy policy
- About section

## Tech Stack

- **SwiftUI**: Modern declarative UI
- **SwiftData**: Local data persistence with CloudKit sync
- **Swift Charts**: Data visualization
- **PhotosUI**: Photo picker integration
- **UserNotifications**: Daily reminder system
- **UITextChecker**: Spell checking / writing assistant

## Project Structure

```
FlowSate/
├── FlowSateApp.swift              # App entry point + iCloud config
├── Item.swift                     # JournalEntry data model
├── HomeView.swift                 # Main dashboard with streak card
├── JournalEditorView.swift        # Entry editor with spell check
├── WeeklyOverviewView.swift       # Weekly stats, charts & mood distribution
├── WeeklyReviewView.swift         # Sunday weekly review
├── EntryLibraryView.swift         # All entries browser with export
├── SettingsView.swift             # App settings (notifications, appearance)
├── NotificationManager.swift      # Push notification scheduling
├── ExportManager.swift            # Export entries as text/JSON
├── StreakManager.swift            # Streak calculation logic
└── PrivacyPolicy.swift            # Privacy policy view
```

## Running the App

1. Open in Xcode 15+
2. Add new Swift files to the FlowSate target if needed
3. For iCloud sync: Enable iCloud capability + CloudKit in Signing & Capabilities
4. Select a simulator (iPhone 15 Pro recommended)
5. Press `Cmd + R` to build and run

## iCloud Setup

To enable iCloud sync:
1. Select the project in Xcode
2. Go to Signing & Capabilities
3. Add "iCloud" capability
4. Check "CloudKit"
5. Add a CloudKit container (e.g., `iCloud.com.yourname.FlowState`)

The app will automatically fall back to local-only storage if CloudKit is not configured.

## Privacy

- All data stored locally on device
- Optional iCloud sync uses Apple's infrastructure only
- No analytics, tracking, or third-party services
- No ads
- User controls all data
