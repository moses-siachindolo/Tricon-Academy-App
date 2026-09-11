"""Compile the production PDF cache on macOS and exercise offline cache behavior."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'views/PDFViewerScreen.swift').read_text()
cache = source[source.index('actor DocumentDownloadCache'):]
harness = r'''
final class OfflineProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

@main struct CacheChecks {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let cache = DocumentDownloadCache(directory: directory, session: session)
        let request = URLRequest(url: URL(string: "https://example.invalid/paper.pdf")!)
        let identity = request.url!.absoluteString + "\n\n"
        let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(key + ".pdf")
        let pdf = PDFDocument()
        pdf.insert(PDFPage(), at: 0)
        precondition(pdf.write(to: file))
        let first = try await cache.document(for: request)
        precondition(first.pageCount == 1)
        let second = try await DocumentDownloadCache(directory: directory, session: session).document(for: request)
        precondition(second.pageCount == 1, "Cache must survive a new cache instance")
        var privateRequest = request
        privateRequest.setValue("Bearer different-session", forHTTPHeaderField: "Authorization")
        await expectFailure(cache, privateRequest)
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSinceNow: -8 * 86400)], ofItemAtPath: file.path)
        await expectFailure(cache, request)
        try FileManager.default.removeItem(at: file)
        try Data("not a PDF".utf8).write(to: file)
        await expectFailure(cache, request)
        do {
            _ = try await cache.localDocument(at: file)
            fatalError("Invalid local PDF was accepted")
        } catch {}
        print("PASS: disk reuse, persistence, session isolation, expiry, corrupt cache and local PDF rejection")
    }

    static func expectFailure(_ cache: DocumentDownloadCache, _ request: URLRequest) async {
        do {
            _ = try await cache.document(for: request)
            fatalError("Expected cache miss and offline failure")
        } catch {}
    }
}
'''
with tempfile.TemporaryDirectory(prefix='tricon-document-tests-') as tmp:
    source_file = Path(tmp) / 'CacheTests.swift'
    binary = Path(tmp) / 'cache-tests'
    source_file.write_text('import Foundation\nimport PDFKit\nimport CryptoKit\n' + cache + harness)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', '/tmp/tricon-swift-module-cache', str(source_file), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
