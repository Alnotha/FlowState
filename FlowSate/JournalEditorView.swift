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
    @State private var photoLoadError: String?
    @State private var showingPhotoError = false
    @State private var moodSuggestion: MoodSuggestion?
    @State private var moodSuggestionDebounce: Task<Void, Never>?

    private let maxPhotos = 10
    private let maxContentLength = 50_000

    private var remainingPhotoSlots: Int {
        maxPhotos - (entry.photoData?.count ?? 0)
    }

    var body: some View {
        List {
            statsSection
            editorSection
            photosSection
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
                .accessibilityLabel("Save entry")
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
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotos,
            maxSelectionCount: max(remainingPhotoSlots, 1),
            matching: .images
        )
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await loadPhotos(newPhotos)
            }
        }
        .moodSuggestion(moodSuggestion, onAccept: { mood in
            entry.mood = mood
            moodSuggestion = nil
        }, onDismiss: {
            moodSuggestion = nil
        })
        .onAppear {
            if entry.content.isEmpty {
                isEditorFocused = true
            }
        }
        .alert("Photo Error", isPresented: $showingPhotoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(photoLoadError ?? "Failed to load photo")
        }
    }

    // MARK: - Extracted Sections

    private var statsSection: some View {
        Section {
            HStack {
                StatItem(label: "Words", value: "\(entry.wordCount)")
                Divider()
                StatItem(label: "Characters", value: "\(entry.content.count)")
                Divider()

                // Mood selector
                VStack(spacing: 4) {
                    if let emoji = entry.moodEmoji {
                        Text(emoji)
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
                    .accessibilityLabel("Select mood")
                    .accessibilityHint("Choose how you're feeling")
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
    }

    private var editorSection: some View {
        Section {
            TextEditor(text: $entry.content)
                .frame(minHeight: 300)
                .focused($isEditorFocused)
                .scrollContentBackground(.hidden)
                .listRowInsets(EdgeInsets())
                .accessibilityLabel("Journal entry text")
                .onChange(of: entry.content) { _, _ in
                    if entry.content.count > maxContentLength {
                        entry.content = String(entry.content.prefix(maxContentLength))
                    }
                    entry.updateWordCount()
                    debounceMoodSuggestion()
                }
        } header: {
            Text("Entry")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }

    private var photosSection: some View {
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
                                    .accessibilityLabel("Photo \(index + 1)")
                                    .accessibilityHint("Double tap to view options")
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

            if remainingPhotoSlots > 0 {
                Button {
                    showingPhotosPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Add Photos (\(entry.photoData?.count ?? 0)/\(maxPhotos))")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(.blue)
                }
                .accessibilityLabel("Add photos")
                .listRowInsets(EdgeInsets())
                .padding()
            } else {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Maximum \(maxPhotos) photos reached")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .listRowInsets(EdgeInsets())
                .padding()
            }
        } header: {
            Text("Photos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }

    // MARK: - Photos

    private func loadPhotos(_ photos: [PhotosPickerItem]) async {
        var photoDataArray: [Data] = entry.photoData ?? []
        var failedCount = 0

        for photo in photos {
            guard photoDataArray.count < maxPhotos else { break }

            do {
                if let data = try await photo.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Resize to max 2048px on longest side
                    let maxDimension: CGFloat = 2048
                    let scale = min(maxDimension / max(uiImage.size.width, uiImage.size.height), 1.0)
                    let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: newSize)
                    let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                    if let compressed = resized.jpegData(compressionQuality: 0.7) {
                        photoDataArray.append(compressed)
                    }
                } else {
                    failedCount += 1
                }
            } catch {
                failedCount += 1
            }
        }

        await MainActor.run {
            entry.photoData = photoDataArray
            selectedPhotos.removeAll()

            if failedCount > 0 {
                photoLoadError = "\(failedCount) photo\(failedCount == 1 ? "" : "s") could not be loaded. Please try again."
                showingPhotoError = true
            }
        }
    }

    private func removePhoto(at index: Int) {
        entry.photoData?.remove(at: index)
        if entry.photoData?.isEmpty == true {
            entry.photoData = nil
        }
    }

    // MARK: - AI Mood Suggestion

    private func debounceMoodSuggestion() {
        moodSuggestionDebounce?.cancel()
        moodSuggestionDebounce = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled,
                  entry.mood == nil,
                  entry.wordCount > 30 else { return }
            moodSuggestion = await AIService.shared.suggestMood(from: entry.content)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

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
