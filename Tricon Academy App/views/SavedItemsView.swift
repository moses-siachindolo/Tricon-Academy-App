import SwiftUI

/// Bookmarks for papers, notes, and videos.
struct SavedItemsView: View {

    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var filter: Int = 0

    private var filtered: [SavedItem] {
        switch filter {
        case 1: return saved.items.filter { $0.kind == .paper }
        case 2: return saved.items.filter { $0.kind == .material }
        case 3: return saved.items.filter { $0.kind == .video }
        default: return saved.items
        }
    }

    private var filterTabs: [ContentTypeSelector.ContentTypeTab] {
        [
            .init(id: 0, title: "All", icon: "square.grid.2x2.fill", color: AppTheme.brandBright, soft: AppTheme.brandSoft, count: saved.items.count),
            .init(id: 1, title: "Papers", icon: "doc.text.fill", color: AppTheme.papers, soft: AppTheme.papersSoft, count: saved.items.filter { $0.kind == .paper }.count),
            .init(id: 2, title: "Notes", icon: "note.text", color: AppTheme.notes, soft: AppTheme.notesSoft, count: saved.items.filter { $0.kind == .material }.count),
            .init(id: 3, title: "Videos", icon: "play.rectangle.fill", color: AppTheme.videos, soft: AppTheme.videosSoft, count: saved.items.filter { $0.kind == .video }.count)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            if saved.items.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    ContentTypeSelector(selection: $filter, tabs: filterTabs, equalWidth: false)
                        .padding(.horizontal, AppTheme.horizontalPadding)
                }
                .padding(.top, 10)
                .padding(.bottom, 12)

                if filtered.isEmpty {
                    AppEmptyState(
                        icon: "bookmark.slash",
                        title: "Nothing in this filter",
                        message: "Try another category, or save more content while browsing.",
                        accent: AppTheme.bookmark,
                        soft: AppTheme.bookmark.opacity(0.14)
                    )
                } else {
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
        }
        .appScreen()
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
        AppEmptyState(
            icon: "bookmark.fill",
            title: "No saved items yet",
            message: "Tap the bookmark on any paper, note, or video to keep it here for quick access.",
            accent: AppTheme.bookmark,
            soft: AppTheme.bookmark.opacity(0.14)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func savedRow(_ item: SavedItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(soft(for: item.kind))
                    .frame(width: 46, height: 46)
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
                    .foregroundColor(AppTheme.bookmark)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppTheme.bookmark.opacity(0.14)))
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.subtle)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 3)
    }

    private func color(for kind: SavedItemKind) -> Color {
        switch kind {
        case .paper: return AppTheme.papers
        case .material: return AppTheme.notes
        case .video: return AppTheme.videos
        }
    }

    private func soft(for kind: SavedItemKind) -> Color {
        switch kind {
        case .paper: return AppTheme.papersSoft
        case .material: return AppTheme.notesSoft
        case .video: return AppTheme.videosSoft
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
