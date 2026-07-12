import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var stats = StatsManager.shared
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var currentQuote: String = HomeView.quotes.randomElement() ?? ""
    @State private var showUploadSheet = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    /// Profile tab index: staff have Manage at 3, so Profile is 4.
    private var profileTabIndex: Int {
        authManager.currentUser?.canManageContent == true ? 4 : 3
    }

    private var manageTabIndex: Int { 3 }

    static let quotes = [
        "Education is the most powerful weapon which you can use to change the world.",
        "Success is the sum of small efforts, repeated day in and day out.",
        "The beautiful thing about learning is that no one can take it away from you.",
        "Push yourself, because no one else is going to do it for you.",
        "Don't watch the clock; do what it does. Keep going.",
        "Believe you can and you're halfway there."
    ]

    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredLevels: [Level] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return Level.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(q) }
    }

    private var filteredSubjects: [Subject] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let core = allSubjects.filter { $0.name.localizedCaseInsensitiveContains(q) }
        let optionals = optionalSubjects.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return core + optionals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                // MARK: Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back,")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(authManager.currentUser?.fullName ?? "Student")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    Button {
                        selectedTab = profileTabIndex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 46, height: 46)
                            Text(initials)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open profile")
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                // Staff-only shortcut: upload + open Manage tab
                if authManager.currentUser?.canManageContent == true {
                    HStack(spacing: 10) {
                        Button {
                            showUploadSheet = true
                        } label: {
                            Label("Upload", systemImage: "arrow.up.doc.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button {
                            selectedTab = manageTabIndex
                        } label: {
                            Label("Manage", systemImage: "slider.horizontal.3")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.green.opacity(0.12))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 22)
                }

                // MARK: Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                    TextField("Search subjects, levels, topics", text: $searchText)
                        .font(.subheadline)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if isSearching {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 22)

                if isSearching {
                    searchResultsSection
                } else {
                    homeContent
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            StatsManager.shared.recordAppActive()
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView()
                .environmentObject(authManager)
        }
    }

    // MARK: - Default home content

    @ViewBuilder
    private var homeContent: some View {
        // Level Grid
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your level")
                .font(.headline)
                .padding(.horizontal, 22)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Level.allCases) { level in
                    NavigationLink(destination: SubjectListView(level: level)) {
                        levelCard(level: level)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
        }

        // Motivational Quote Banner
        Button {
            withAnimation {
                currentQuote = HomeView.quotes.randomElement() ?? currentQuote
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.75, green: 0.9, blue: 0.75))

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentQuote)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Text("Tap for another")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.22, blue: 0.15), Color(red: 0.02, green: 0.12, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .accessibilityLabel("Motivational quote. Tap for another.")

        // This Week Stats
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.headline)
                .padding(.horizontal, 22)

            HStack(spacing: 10) {
                statCard(icon: "doc.text.fill", value: "\(stats.papersSolvedThisWeek)", label: "Papers opened", color: .blue)
                statCard(icon: "play.rectangle.fill", value: "\(stats.videosWatchedThisWeek)", label: "Videos watched", color: .purple)
                statCard(icon: "flame.fill", value: "\(stats.dayStreak)", label: "Day streak", color: .orange)
            }
            .padding(.horizontal, 22)
        }

        // Quick Access
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick access")
                .font(.headline)
                .padding(.horizontal, 22)

            HStack(spacing: 10) {
                quickAccessCard(
                    icon: "doc.text.fill", title: "Papers", color: .blue,
                    destination: BrowseLevelsView(title: "Papers", subtitle: "Choose a level to browse past papers.", targetTab: 0)
                )
                Button {
                    selectedTab = 2
                } label: {
                    quickAccessLabel(icon: "bookmark.fill", title: "Saved", color: .orange)
                }
                .buttonStyle(.plain)
                quickAccessCard(
                    icon: "play.rectangle.fill", title: "Videos", color: .purple,
                    destination: BrowseLevelsView(title: "Videos", subtitle: "Choose a level to browse videos.", targetTab: 2)
                )
                quickAccessCard(
                    icon: "note.text", title: "Notes", color: .teal,
                    destination: BrowseLevelsView(title: "Notes", subtitle: "Choose a level to browse notes.", targetTab: 1)
                )
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredLevels.isEmpty && filteredSubjects.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No results for “\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))”")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Try a subject name like Physics, or a level like Form 1.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 22)
            } else {
                if !filteredLevels.isEmpty {
                    Text("Levels")
                        .font(.headline)
                        .padding(.horizontal, 22)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredLevels) { level in
                            NavigationLink(destination: SubjectListView(level: level)) {
                                levelCard(level: level)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                }

                if !filteredSubjects.isEmpty {
                    Text("Subjects")
                        .font(.headline)
                        .padding(.horizontal, 22)

                    VStack(spacing: 10) {
                        ForEach(filteredSubjects) { subject in
                            NavigationLink(destination: SubjectLevelPickerView(subject: subject)) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(subject.swiftUIColor.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: subject.icon)
                                            .font(.system(size: 16))
                                            .foregroundColor(subject.swiftUIColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subject.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("Choose a level to open")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    private var initials: String {
        let name = authManager.currentUser?.fullName ?? "S"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    @ViewBuilder
    private func levelCard(level: Level) -> some View {
        VStack(spacing: 8) {
            Image(systemName: level.icon)
                .font(.system(size: 30))
                .foregroundColor(.green)

            Text(level.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("\(allSubjects.count) subjects")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 90)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private func quickAccessCard<Destination: View>(icon: String, title: String, color: Color, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            quickAccessLabel(icon: icon, title: title, color: color)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func quickAccessLabel(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
        }
        .environmentObject(AuthManager.shared)
    }
}
