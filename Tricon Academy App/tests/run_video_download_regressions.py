"""Compile the production video store and check durable, account-specific offline playback."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'views/VideoPlayerScreen.swift').read_text()
store = source[source.index('actor VideoDownloadStore'):]
harness = r'''
@main struct VideoChecks {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let user = UUID()
        let remote = URL(string: "https://example.invalid/lesson.mov")!
        let identity = remote.absoluteString + "\naccount:" + user.uuidString.lowercased()
        let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(key + ".mov")
        let writer = try AVAssetWriter(outputURL: file, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 32, AVVideoHeightKey: 32
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 32, kCVPixelBufferHeightKey as String: 32
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? URLError(.cannotCreateFile) }
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        precondition(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32ARGB, nil, &buffer) == kCVReturnSuccess)
        let pixel = buffer!
        CVPixelBufferLockBaseAddress(pixel, [])
        memset(CVPixelBufferGetBaseAddress(pixel)!, 0, CVPixelBufferGetDataSize(pixel))
        CVPixelBufferUnlockBaseAddress(pixel, [])
        let deadline = Date().addingTimeInterval(10)
        while !input.isReadyForMoreMediaData && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(input.isReadyForMoreMediaData)
        precondition(adaptor.append(pixel, withPresentationTime: .zero))
        input.markAsFinished()
        await writer.finishWriting()
        precondition(writer.status == .completed)
        let store = VideoDownloadStore(directory: directory)
        let local = await store.cachedVideo(for: remote, userID: user)
        precondition(local == file, "Completed video must open from disk")
        let relaunched = await VideoDownloadStore(directory: directory).cachedVideo(for: remote, userID: user)
        precondition(relaunched == file, "Offline video must survive relaunch")
        let other = await store.cachedVideo(for: remote, userID: UUID())
        precondition(other == nil, "Accounts cannot share private video downloads")
        let signedOut = await store.cachedVideo(for: remote, userID: nil)
        precondition(signedOut == nil)
        try Data("not a video".utf8).write(to: file)
        let corrupt = await store.cachedVideo(for: remote, userID: user)
        precondition(corrupt == nil, "Corrupt downloads must not be offered for playback")
        print("PASS: offline video playback, relaunch, account isolation, signed-out isolation, corrupt file rejection")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='tricon-video-tests-') as tmp:
    swift = Path(tmp) / 'VideoTests.swift'
    binary = Path(tmp) / 'video-tests'
    swift.write_text('import Foundation\nimport AVFoundation\nimport CryptoKit\n' + store + harness)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', '/tmp/tricon-swift-module-cache', str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
