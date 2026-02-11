//
//  ExportManager.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case text = "Plain Text"
    case json = "JSON"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        }
    }

    var iconName: String {
        switch self {
        case .text: return "doc.plaintext"
        case .json: return "curlybraces"
        }
    }
}

// MARK: - Export Manager

final class ExportManager {

    func exportAsText(entries: [JournalEntry]) -> String {
        guard !entries.isEmpty else {
            return "FlowState Journal\n\nNo entries to export."
        }

        let sorted = entries.sorted { $0.date > $1.date }
        var lines: [String] = []
        lines.append("FlowState Journal")
        lines.append("Exported on \(formattedCurrentDate())")
        lines.append("Entries: \(sorted.count)")
        lines.append(String(repeating: "=", count: 40))
        lines.append("")

        for entry in sorted {
            lines.append(entry.formattedDate)
            lines.append(String(repeating: "-", count: 30))

            if let mood = entry.mood {
                lines.append("Mood: \(moodEmoji(for: mood)) \(mood.capitalized)")
            }

            lines.append("Words: \(entry.wordCount)")

            if let photoData = entry.photoData, !photoData.isEmpty {
                lines.append("Photos: \(photoData.count)")
            }

            lines.append("")

            if entry.content.isEmpty {
                lines.append("(No content)")
            } else {
                lines.append(entry.content)
            }

            lines.append("")
            lines.append(String(repeating: "=", count: 40))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    func exportAsJSON(entries: [JournalEntry]) -> Data? {
        let sorted = entries.sorted { $0.date > $1.date }

        let exportable = sorted.map { entry -> [String: Any] in
            var dict: [String: Any] = [
                "id": entry.id.uuidString,
                "date": ISO8601DateFormatter().string(from: entry.date),
                "formattedDate": entry.formattedDate,
                "content": entry.content,
                "wordCount": entry.wordCount
            ]

            if let mood = entry.mood {
                dict["mood"] = mood
                dict["moodEmoji"] = moodEmoji(for: mood)
            }

            if let photoData = entry.photoData {
                dict["photoCount"] = photoData.count
            }

            return dict
        }

        let wrapper: [String: Any] = [
            "appName": "FlowState",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "entryCount": exportable.count,
            "entries": exportable
        ]

        return try? JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
    }

    func createExportFileURL(entries: [JournalEntry], format: ExportFormat) -> URL? {
        let fileName = "FlowState_Export_\(filenameDateString()).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        switch format {
        case .text:
            let text = exportAsText(entries: entries)
            do {
                try text.write(to: tempURL, atomically: true, encoding: .utf8)
                return tempURL
            } catch {
                return nil
            }
        case .json:
            guard let data = exportAsJSON(entries: entries) else { return nil }
            do {
                try data.write(to: tempURL, options: .atomic)
                return tempURL
            } catch {
                return nil
            }
        }
    }

    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    private func filenameDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Sheet View

struct ExportSheet: View {
    let entries: [JournalEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .text
    @State private var showingActivitySheet = false
    @State private var exportFileURL: URL?

    private let exportManager = ExportManager()

    private var previewText: String {
        switch selectedFormat {
        case .text:
            let full = exportManager.exportAsText(entries: entries)
            return String(full.prefix(500)) + (full.count > 500 ? "\n..." : "")
        case .json:
            if let data = exportManager.exportAsJSON(entries: entries),
               let string = String(data: data, encoding: .utf8) {
                return String(string.prefix(500)) + (string.count > 500 ? "\n..." : "")
            }
            return "Unable to generate preview."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            selectedFormat = format
                        } label: {
                            HStack {
                                Image(systemName: format.iconName)
                                    .font(.body)
                                    .frame(width: 28)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.rawValue)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(".\(format.fileExtension) file")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedFormat == format {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Export Format")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }

                Section {
                    HStack {
                        Text("Entries")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(entries.count)")
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Total Words")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(entries.reduce(0) { $0 + $1.wordCount })")
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }

                Section {
                    Text(previewText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(12)
                } header: {
                    Text("Preview")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareAndShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .sheet(isPresented: $showingActivitySheet) {
                if let url = exportFileURL {
                    ActivityViewController(activityItems: [url])
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func prepareAndShare() {
        exportFileURL = exportManager.createExportFileURL(entries: entries, format: selectedFormat)
        if exportFileURL != nil {
            showingActivitySheet = true
        }
    }
}

// MARK: - UIActivityViewController Wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportSheet(entries: [])
}
