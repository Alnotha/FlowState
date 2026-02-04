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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Date header
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .complete, time: .omitted))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Word count indicator
                HStack {
                    Label("\(entry.wordCount) words", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Mood selector (placeholder for now)
                    Menu {
                        Button("😊 Happy") { entry.mood = "happy" }
                        Button("😌 Calm") { entry.mood = "calm" }
                        Button("😔 Sad") { entry.mood = "sad" }
                        Button("😤 Frustrated") { entry.mood = "frustrated" }
                        Button("🤔 Thoughtful") { entry.mood = "thoughtful" }
                    } label: {
                        Label(entry.mood?.capitalized ?? "Set Mood", systemImage: "face.smiling")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                // Text editor
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $entry.content)
                        .frame(minHeight: 300)
                        .focused($isEditorFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .onChange(of: entry.content) { _, _ in
                            entry.updateWordCount()
                        }
                    
                    Text("How was your day? What are you thinking about?")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // Photos section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Photos")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            showingPhotosPicker = true
                        } label: {
                            Label("Add Photo", systemImage: "photo.badge.plus")
                                .font(.caption)
                        }
                    }
                    
                    if let photoData = entry.photoData, !photoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photoData.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: photoData[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
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
                        }
                    } else {
                        Button {
                            showingPhotosPicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                
                                Text("Add photos to your entry")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                // Writing tips card (placeholder for writing assistant)
                WritingTipsCard()
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
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
}

// MARK: - Writing Tips Card

struct WritingTipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Writing Assistant", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.purple)
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "checkmark.circle.fill", text: "Grammar and spelling look good", color: .green)
                TipRow(icon: "info.circle.fill", text: "Try being more specific about emotions", color: .blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        JournalEditorView(entry: JournalEntry(content: "Today was a great day!"))
            .modelContainer(for: JournalEntry.self, inMemory: true)
    }
}
