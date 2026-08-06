import SwiftUI

/// Bookmarks for papers, notes, and videos.
struct SavedItemsView: View {

    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case papers = "Papers"
        case notes = "Notes"
        case videos = "Videos"

        var id: String { rawValue }
    }

    private var filtered: [SavedItem] {
        switch filter {
        case .all: return saved.items
        case .papers: return saved.items.filter { $0.kind == .paper }
        case .notes: return saved.items.filter { $0.kind == .material }
        case .videos: return saved.items.filter { $0.kind == .video }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if saved.items.isEmpty {
                emptyState
            } else {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { item in
                            NavigationLink(destination: destination(for: item)) {
                                savedRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.bottom, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !saved.items.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        saved.clearAll()
                    }
                    .foregroundColor(AppTheme.danger)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.48, blue: 0.18).opacity(0.14))
                    .frame(width: 78, height: 78)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(Color(red: 0.95, green: 0.48, blue: 0.18))
            }
            Text("No saved items yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.ink)
            Text("Tap the bookmark on any paper, note, or video to keep it here for quick access.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func savedRow(_ item: SavedItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color(for: item.kind).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color(for: item.kind))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(2)
                Text("\(item.subjectName) · \(item.subtitle)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                saved.remove(id: item.id)
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.95, green: 0.48, blue: 0.18))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.04)))
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.muted.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    private func color(for kind: SavedItemKind) -> Color {
        switch kind {
        case .paper: return Color(red: 0.20, green: 0.48, blue: 0.92)
        case .material: return Color(red: 0.10, green: 0.62, blue: 0.55)
        case .video: return Color(red: 0.52, green: 0.32, blue: 0.88)
        }
    }

    @ViewBuilder
    private func destination(for item: SavedItem) -> some View {
        switch item.kind {
        case .paper, .material:
            PDFViewerScreen(
                fileName: item.fileName,
                title: item.title,
                isPastPaper: item.isPastPaper,
                contentId: item.id,
                subjectName: item.subjectName,
                levelRaw: item.levelRaw,
                topic: item.kind == .material ? item.subtitle : ""
            )
        case .video:
            VideoPlayerScreen(
                fileName: item.fileName,
                fileExtension: item.fileExtension,
                title: item.title,
                contentId: item.id,
                topic: item.subtitle,
                subjectName: item.subjectName,
                levelRaw: item.levelRaw
            )
        }
    }
}

struct SavedItemsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SavedItemsView()
        }
    }
}
