//
//  Item.swift (JournalEntry)
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//  Note: This file contains the JournalEntry model. File is named Item.swift for Xcode project compatibility.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var content: String
    var mood: String?
    @Attribute(.externalStorage) var photoData: [Data]? // Store image data
    var wordCount: Int
    var aiSuggestedMood: String?
    var themes: [String]?
    
    init(date: Date = Date(), content: String = "", mood: String? = nil, photoData: [Data]? = nil) {
        self.id = UUID()
        self.date = date
        self.content = content
        self.mood = mood
        self.photoData = photoData
        self.wordCount = content.wordCount
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Check if entry is from today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    // Update word count when content changes
    func updateWordCount() {
        wordCount = content.wordCount
    }

    // Emoji representation of the mood
    var moodEmoji: String? {
        guard let mood = mood else { return nil }
        return FlowSate.moodEmoji(for: mood)
    }
}

// MARK: - Shared Helpers

func moodEmoji(for mood: String) -> String {
    switch mood.lowercased() {
    case "happy": return "😊"
    case "calm": return "😌"
    case "sad": return "😔"
    case "frustrated": return "😤"
    case "thoughtful": return "🤔"
    default: return "😐"
    }
}

extension String {
    var wordCount: Int {
        var count = 0
        enumerateSubstrings(in: startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
