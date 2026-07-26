import Foundation

/// Where offline content lives: full static-Space snapshots (playable with no
/// network) and cached article HTML. Under Application Support so it persists.
enum OfflineStore {
    private static var appSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "hf.app")
    }
    static var spacesRoot: URL { appSupport.appending(path: "spaces") }
    static var articlesRoot: URL { appSupport.appending(path: "articles") }

    // MARK: Spaces
    static func spaceDir(_ id: String) -> URL {
        spacesRoot.appending(path: id.replacingOccurrences(of: "/", with: "__"))
    }

    static func isSpaceDownloaded(_ id: String) -> Bool {
        let dir = spaceDir(id)
        guard FileManager.default.fileExists(atPath: dir.path) else { return false }
        let idx = dir.appending(path: "index.html")
        if FileManager.default.fileExists(atPath: idx.path) { return true }
        // Fallback: check if the directory contains any .html file.
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.contains(where: { $0.hasSuffix(".html") || $0.hasSuffix(".htm") })
    }

    static func spaceIndex(_ id: String) -> URL? {
        let dir = spaceDir(id)
        let idx = dir.appending(path: "index.html")
        if FileManager.default.fileExists(atPath: idx.path) { return idx }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        if let html = files.first(where: { $0.hasSuffix(".html") || $0.hasSuffix(".htm") }) {
            return dir.appending(path: html)
        }
        return nil
    }

    static func removeSpace(_ id: String) {
        try? FileManager.default.removeItem(at: spaceDir(id))
    }

    // MARK: Articles
    static func articleFile(_ link: String) -> URL {
        let key = link.replacingOccurrences(of: "[^A-Za-z0-9]", with: "_", options: .regularExpression)
        return articlesRoot.appending(path: key + ".html")
    }
    static func isArticleCached(_ link: String) -> Bool {
        FileManager.default.fileExists(atPath: articleFile(link).path)
    }

    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
