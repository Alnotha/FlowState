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
    var photoData: [Data]? // Store image data
    var wordCount: Int
    var aiSuggestedMood: String?
    var themes: [String]?
    
    init(date: Date = Date(), content: String = "", mood: String? = nil, photoData: [Data]? = nil) {
        self.id = UUID()
        self.date = date
        self.content = content
        self.mood = mood
        self.photoData = photoData
        self.wordCount = content.split(separator: " ").count
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
        wordCount = content.isEmpty ? 0 : content.split(separator: " ").count
    }

    // Emoji representation of the mood
    var moodEmoji: String? {
        guard let mood = mood else { return nil }
        switch mood.lowercased() {
        case "happy": return "😊"
        case "calm": return "😌"
        case "sad": return "😔"
        case "frustrated": return "😤"
        case "thoughtful": return "🤔"
        default: return "😐"
        }
    }
}
