import SwiftUI

/// Destination for the Home screen's "Saved" quick access tile.
/// There's no bookmarking feature yet, so this honestly shows an empty
/// state instead of pretending to be a working list.
struct SavedItemsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 70, height: 70)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }

            Text("No saved items yet")
                .font(.headline)

            Text("Bookmark papers, notes or videos and they'll show up here.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedItemsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SavedItemsView()
        }
    }
}
