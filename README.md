# FlowState

A minimal iOS journaling app built with SwiftUI and SwiftData. Track your thoughts, mood, and writing habits with a clean, data-first interface.

## Features

- **Daily journaling** with auto word count and character tracking
- **Mood tracking** — Happy, Calm, Sad, Frustrated, Thoughtful
- **Photo attachments** — up to 10 per entry via native PhotosUI
- **Weekly dashboard** — bar charts, streaks, mood distribution
- **AI insights** — theme detection and mood suggestions (via Cloudflare Workers AI)
- **Entry library** — full-text search, monthly grouping, swipe-to-delete
- **Export** — text or JSON with share sheet
- **Daily reminders** — configurable push notifications
- **Sign in with Apple** — optional authentication
- **Privacy first** — all data stored locally, optional iCloud sync

## Requirements

- iOS 17+
- Xcode 15+
- Swift 5.9+

## Getting Started

```bash
# Clone and open
git clone <repo-url>
open FlowSate.xcodeproj
```

Select an iOS Simulator (iPhone 15 Pro recommended) and press **Cmd+R** to build and run.

### Command Line Build

```bash
xcodebuild -project FlowSate.xcodeproj -scheme FlowSate \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Run Tests

```bash
xcodebuild -project FlowSate.xcodeproj -scheme FlowSate \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test
```

## Project Structure

```
FlowSate/
├── FlowSateApp.swift                 # App entry point, ModelContainer, iCloud config
├── Item.swift                        # JournalEntry @Model (data model)
├── HomeView.swift                    # Dashboard — greeting, streak card, recent entries
├── JournalEditorView.swift           # Entry editor — text, mood, photos, spell check
├── WeeklyOverviewView.swift          # Weekly stats, bar chart, achievements
├── WeeklyReviewView.swift            # Sunday weekly review recap
├── EntryLibraryView.swift            # Searchable entry browser with export
├── SettingsView.swift                # Notifications, appearance, export, about
├── StreakManager.swift               # Streak calculation logic
├── NotificationManager.swift         # Push notification scheduling
├── ExportManager.swift               # Export entries as text/JSON
├── PrivacyPolicy.swift               # Privacy policy view
├── Models/
│   ├── AIModels.swift                # AI feature data types
│   └── AuthModels.swift              # Authentication data types
├── Services/
│   ├── AIService.swift               # AI-powered insights via Cloudflare Workers
│   ├── AuthenticationManager.swift   # Sign in with Apple
│   ├── CloudflareClient.swift        # Cloudflare API client
│   └── KeychainManager.swift         # Secure credential storage
└── Views/
    ├── AISettingsView.swift           # AI feature configuration
    ├── JournalChatView.swift          # Chat-style AI interaction
    ├── ThemeInsightsView.swift        # AI-detected writing themes
    └── Components/
        ├── MoodSuggestionBanner.swift # AI mood suggestion UI
        ├── NudgeBanner.swift          # Writing nudge prompts
        └── SmartPromptCard.swift      # AI-generated prompts
```

## Architecture

### Data Layer

**SwiftData** with a single `JournalEntry` model persisted locally. CloudKit sync is attempted automatically — falls back to local-only if the iCloud entitlement isn't configured.

```
JournalEntry
├── id: UUID
├── date: Date
├── content: String
├── mood: String?              # "happy", "calm", "sad", "frustrated", "thoughtful"
├── photoData: [Data]?         # @Attribute(.externalStorage)
├── wordCount: Int
├── aiSuggestedMood: String?
└── themes: [String]?
```

### View Hierarchy

```
FlowSateApp
└── HomeView (NavigationStack)
    ├── WeeklyStreakCard        → streak dots, calendar overview
    ├── TodayEntryCard         → today's entry preview → JournalEditorView (sheet)
    ├── EntryRowCard[]         → recent entries → JournalEditorView (push)
    ├── EntryLibraryView       → all entries browser
    ├── WeeklyOverviewView     → stats dashboard
    ├── WeeklyReviewView       → Sunday recap
    └── SettingsView           → app configuration
```

### Key Patterns

- `@Query(sort:order:)` for reactive data fetching
- `@Bindable` for two-way model binding in editors
- `@Environment(\.modelContext)` for create/delete operations
- `@AppStorage` for user preferences (color scheme, notifications)
- Nested helper views within parent files (not separate files)
- `// MARK: -` pragmas for code organization

## iCloud Sync Setup

1. Select the project in Xcode
2. Go to **Signing & Capabilities**
3. Add **iCloud** capability
4. Check **CloudKit**
5. Add a container (e.g., `iCloud.com.yourname.FlowState`)

The app falls back to local storage if CloudKit isn't configured.

## AI Features Setup

AI features (mood suggestions, theme detection, smart prompts) use Cloudflare Workers AI. Configure your API endpoint and token in the AI Settings screen within the app.

## License

All rights reserved. Created by Alyan Tharani, January 2026.
