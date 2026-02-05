//
//  JournalEditorView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: JournalEntry
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingPhotosPicker = false
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        List {
            // Stats Section
            Section {
                HStack {
                    StatItem(label: "Words", value: "\(entry.wordCount)")
                    Divider()
                    StatItem(label: "Characters", value: "\(entry.content.count)")
                    Divider()
                    
                    // Mood selector
                    VStack(spacing: 4) {
                        if let mood = entry.mood {
                            Text(moodEmoji(for: mood))
                                .font(.title2)
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        
                        Menu {
                            Button("😊 Happy") { entry.mood = "happy" }
                            Button("😌 Calm") { entry.mood = "calm" }
                            Button("😔 Sad") { entry.mood = "sad" }
                            Button("😤 Frustrated") { entry.mood = "frustrated" }
                            Button("🤔 Thoughtful") { entry.mood = "thoughtful" }
                            if entry.mood != nil {
                                Divider()
                                Button("Clear", role: .destructive) { entry.mood = nil }
                            }
                        } label: {
                            Text(entry.mood?.capitalized ?? "Mood")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets())
                .padding()
            } header: {
                Text(entry.date.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
            
            // Text Editor Section
            Section {
                TextEditor(text: $entry.content)
                    .frame(minHeight: 300)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .listRowInsets(EdgeInsets())
                    .onChange(of: entry.content) { _, _ in
                        entry.updateWordCount()
                    }
            } header: {
                Text("Entry")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
            
            // Photos Section
            Section {
                if let photoData = entry.photoData, !photoData.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photoData.indices, id: \.self) { index in
                                if let uiImage = UIImage(data: photoData[index]) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                removePhoto(at: index)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                
                Button {
                    showingPhotosPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Add Photos")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(.blue)
                }
                .listRowInsets(EdgeInsets())
                .padding()
            } header: {
                Text("Photos")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button {
                    isEditorFocused = false
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                }
            }
        }
        .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotos, maxSelectionCount: 10, matching: .images)
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await loadPhotos(newPhotos)
            }
        }
        .onAppear {
            // Auto-focus on editor for new entries
            if entry.content.isEmpty {
                isEditorFocused = true
            }
        }
    }
    
    private func loadPhotos(_ photos: [PhotosPickerItem]) async {
        var photoDataArray: [Data] = entry.photoData ?? []
        
        for photo in photos {
            if let data = try? await photo.loadTransferable(type: Data.self) {
                photoDataArray.append(data)
            }
        }
        
        entry.photoData = photoDataArray
        selectedPhotos.removeAll()
    }
    
    private func removePhoto(at index: Int) {
        entry.photoData?.remove(at: index)
        if entry.photoData?.isEmpty == true {
            entry.photoData = nil
        }
    }
    
    private func moodEmoji(for mood: String) -> String {
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

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Comment out preview temporarily if it's causing issues
// You can test by running the app directly instead

/*
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalEntry.self, configurations: config)
    let entry = JournalEntry(content: "Today was a great day!")
    container.mainContext.insert(entry)
    
    return NavigationStack {
        JournalEditorView(entry: entry)
            .modelContainer(container)
    }
}
*/
