//
//  FlowSateTests.swift
//  FlowSateTests
//
//  Created by Alyan Tharani on 1/2/26.
//

import Testing
import Foundation
@testable import FlowSate

// MARK: - Test Helpers

private func dateBySubtractingDays(_ daysAgo: Int) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        .addingTimeInterval(12 * 60 * 60)
}

private func makeEntry(daysAgo: Int = 0, content: String = "Some test content here", mood: String? = nil, photoData: [Data]? = nil) -> JournalEntry {
    JournalEntry(date: dateBySubtractingDays(daysAgo), content: content, mood: mood, photoData: photoData)
}

// MARK: - JournalEntry Model Tests

struct JournalEntryInitTests {

    @Test("Default initialization produces empty content, today's date, and zero word count")
    func defaultInit() {
        let entry = JournalEntry()
        #expect(entry.content == "")
        #expect(entry.wordCount == 0)
        #expect(entry.mood == nil)
        #expect(entry.photoData == nil)
        #expect(Calendar.current.isDateInToday(entry.date))
    }

    @Test("Initialization with content calculates word count correctly")
    func initWithContent() {
        let entry = JournalEntry(content: "Hello world this is a test")
        #expect(entry.wordCount == 6)
    }

    @Test("Each entry gets a unique UUID")
    func uniqueIDs() {
        let entry1 = JournalEntry()
        let entry2 = JournalEntry()
        #expect(entry1.id != entry2.id)
    }

    @Test("Initialization with all parameters")
    func initWithAllParams() {
        let date = dateBySubtractingDays(5)
        let photoBytes: [Data] = [Data([0x01, 0x02]), Data([0x03, 0x04])]
        let entry = JournalEntry(date: date, content: "Test entry", mood: "happy", photoData: photoBytes)

        #expect(entry.date == date)
        #expect(entry.content == "Test entry")
        #expect(entry.mood == "happy")
        #expect(entry.photoData?.count == 2)
        #expect(entry.wordCount == 2)
    }
}

struct JournalEntryWordCountTests {

    @Test("updateWordCount with regular content")
    func updateWordCountRegular() {
        let entry = JournalEntry(content: "one two three")
        entry.content = "a b c d e"
        entry.updateWordCount()
        #expect(entry.wordCount == 5)
    }

    @Test("updateWordCount with empty string sets word count to 0")
    func updateWordCountEmpty() {
        let entry = JournalEntry(content: "some initial words")
        entry.content = ""
        entry.updateWordCount()
        #expect(entry.wordCount == 0)
    }

    @Test("Word count handles multiple consecutive spaces")
    func wordCountMultipleSpaces() {
        let entry = JournalEntry(content: "hello   world   test")
        #expect(entry.wordCount == 3)
    }

    @Test("Word count handles leading and trailing spaces")
    func wordCountLeadingTrailingSpaces() {
        let entry = JournalEntry(content: "  hello world  ")
        #expect(entry.wordCount == 2)
    }

    @Test("Word count with special characters")
    func wordCountSpecialChars() {
        let entry = JournalEntry(content: "hello, world! how are you?")
        #expect(entry.wordCount == 5)
    }

    @Test("Word count with only spaces yields 0")
    func wordCountOnlySpaces() {
        let entry = JournalEntry(content: "     ")
        #expect(entry.wordCount == 0)
    }

    @Test("updateWordCount reflects content mutation")
    func updateWordCountAfterMutation() {
        let entry = JournalEntry(content: "one")
        #expect(entry.wordCount == 1)

        entry.content = "one two three four five"
        entry.updateWordCount()
        #expect(entry.wordCount == 5)

        entry.content = ""
        entry.updateWordCount()
        #expect(entry.wordCount == 0)
    }
}

struct JournalEntryDateTests {

    @Test("isToday returns true for entry created today")
    func isTodayTrue() {
        let entry = JournalEntry()
        #expect(entry.isToday == true)
    }

    @Test("isToday returns false for entry created yesterday")
    func isTodayFalseYesterday() {
        let entry = makeEntry(daysAgo: 1)
        #expect(entry.isToday == false)
    }

    @Test("formattedDate returns a non-empty string")
    func formattedDateNonEmpty() {
        let entry = JournalEntry()
        #expect(!entry.formattedDate.isEmpty)
    }
}

struct JournalEntryMoodTests {

    @Test("Mood defaults to nil")
    func moodDefaultNil() {
        let entry = JournalEntry()
        #expect(entry.mood == nil)
    }

    @Test("Mood can be set and changed")
    func moodCanBeSet() {
        let entry = JournalEntry()
        entry.mood = "happy"
        #expect(entry.mood == "happy")

        entry.mood = "sad"
        #expect(entry.mood == "sad")
    }

    @Test("Mood can be cleared back to nil")
    func moodCanBeCleared() {
        let entry = JournalEntry(mood: "calm")
        entry.mood = nil
        #expect(entry.mood == nil)
    }
}

struct JournalEntryPhotoDataTests {

    @Test("photoData defaults to nil")
    func photoDataDefaultNil() {
        let entry = JournalEntry()
        #expect(entry.photoData == nil)
    }

    @Test("photoData can be initialized with data")
    func photoDataInit() {
        let data = [Data([0xFF, 0xD8, 0xFF])]
        let entry = JournalEntry(photoData: data)
        #expect(entry.photoData?.count == 1)
    }

    @Test("photoData can be appended and cleared")
    func photoDataAppendAndClear() {
        let entry = JournalEntry(photoData: [Data([0x01])])
        entry.photoData?.append(Data([0x02]))
        #expect(entry.photoData?.count == 2)

        entry.photoData = nil
        #expect(entry.photoData == nil)
    }
}

// MARK: - StreakManager Tests

struct StreakManagerCurrentStreakTests {

    @Test("currentStreak with no entries returns 0")
    func currentStreakEmpty() {
        #expect(StreakManager.currentStreak(from: []) == 0)
    }

    @Test("currentStreak with only today returns 1")
    func currentStreakTodayOnly() {
        let entries = [makeEntry(daysAgo: 0)]
        #expect(StreakManager.currentStreak(from: entries) == 1)
    }

    @Test("currentStreak with consecutive days including today")
    func currentStreakConsecutive() {
        let entries = (0..<5).map { makeEntry(daysAgo: $0) }
        #expect(StreakManager.currentStreak(from: entries) == 5)
    }

    @Test("currentStreak resets when there is a gap")
    func currentStreakResetsOnGap() {
        let entries = [
            makeEntry(daysAgo: 0),
            makeEntry(daysAgo: 1),
            makeEntry(daysAgo: 3),
            makeEntry(daysAgo: 4)
        ]
        #expect(StreakManager.currentStreak(from: entries) == 2)
    }

    @Test("currentStreak counts from yesterday if no entry today")
    func currentStreakFromYesterday() {
        let entries = [
            makeEntry(daysAgo: 1),
            makeEntry(daysAgo: 2),
            makeEntry(daysAgo: 3)
        ]
        #expect(StreakManager.currentStreak(from: entries) == 3)
    }

    @Test("currentStreak returns 0 when most recent entry is 2+ days ago")
    func currentStreakOldEntries() {
        let entries = [makeEntry(daysAgo: 5), makeEntry(daysAgo: 6)]
        #expect(StreakManager.currentStreak(from: entries) == 0)
    }
}

struct StreakManagerLongestStreakTests {

    @Test("longestStreak with no entries returns 0")
    func longestStreakEmpty() {
        #expect(StreakManager.longestStreak(from: []) == 0)
    }

    @Test("longestStreak with single entry returns 1")
    func longestStreakSingleEntry() {
        let entries = [makeEntry(daysAgo: 10)]
        #expect(StreakManager.longestStreak(from: entries) == 1)
    }

    @Test("longestStreak finds longest run")
    func longestStreakFindsLongest() {
        let entries = [
            makeEntry(daysAgo: 0),
            makeEntry(daysAgo: 1),
            makeEntry(daysAgo: 3),
            makeEntry(daysAgo: 4),
            makeEntry(daysAgo: 5),
            makeEntry(daysAgo: 6),
            makeEntry(daysAgo: 8)
        ]
        #expect(StreakManager.longestStreak(from: entries) == 4)
    }

    @Test("longestStreak with all consecutive days")
    func longestStreakAllConsecutive() {
        let entries = (0..<7).map { makeEntry(daysAgo: $0) }
        #expect(StreakManager.longestStreak(from: entries) == 7)
    }
}

struct StreakManagerUtilityTests {

    @Test("averageWordsPerEntry with no entries returns 0")
    func averageWordsEmpty() {
        #expect(StreakManager.averageWordsPerEntry(from: []) == 0)
    }

    @Test("averageWordsPerEntry calculates correctly")
    func averageWordsCalculation() {
        let entries = [
            makeEntry(daysAgo: 0, content: "one two three"),
            makeEntry(daysAgo: 1, content: "four five six seven"),
            makeEntry(daysAgo: 2, content: "eight nine")
        ]
        #expect(StreakManager.averageWordsPerEntry(from: entries) == 3)
    }

    @Test("journaledToday returns true when there is an entry today")
    func journaledTodayTrue() {
        let entries = [makeEntry(daysAgo: 0)]
        #expect(StreakManager.journaledToday(from: entries) == true)
    }

    @Test("journaledToday returns false when no entry today")
    func journaledTodayFalse() {
        let entries = [makeEntry(daysAgo: 1)]
        #expect(StreakManager.journaledToday(from: entries) == false)
    }

    @Test("journaledToday returns false for empty entries")
    func journaledTodayEmpty() {
        #expect(StreakManager.journaledToday(from: []) == false)
    }

    @Test("totalEntries counts all entries")
    func totalEntriesCounts() {
        let entries = (0..<10).map { makeEntry(daysAgo: $0) }
        #expect(StreakManager.totalEntries(from: entries) == 10)
    }

    @Test("thisWeekCount counts entries in current week")
    func thisWeekCounts() {
        let todayEntry = makeEntry(daysAgo: 0)
        let oldEntry = makeEntry(daysAgo: 30)
        #expect(StreakManager.thisWeekCount(from: [todayEntry, oldEntry]) == 1)
    }

    @Test("thisMonthCount counts entries in current month")
    func thisMonthCounts() {
        let todayEntry = makeEntry(daysAgo: 0)
        let oldEntry = makeEntry(daysAgo: 90)
        #expect(StreakManager.thisMonthCount(from: [todayEntry, oldEntry]) == 1)
    }
}
