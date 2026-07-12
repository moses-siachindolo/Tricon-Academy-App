import SwiftUI
import AVKit

struct VideoPlayerScreen: View {

    let fileName: String
    let fileExtension: String
    let title: String

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
                VideoPlayer(player: AVPlayer(url: url))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Video not found in bundle")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            StatsManager.shared.recordVideoWatched()
        }
    }
}
