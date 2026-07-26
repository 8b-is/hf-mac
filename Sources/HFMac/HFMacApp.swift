import SwiftUI

// hf.app — a native macOS Hugging Face client. Play Spaces on the desktop
// (your quantum games), read offline, and run models locally via Osaurus.
@main
struct HFMacApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
                .task { await state.bootstrap() }
        }
        .defaultSize(width: 1140, height: 760)

        MenuBarExtra("hf", systemImage: "brain.head.profile") {
            MenuBarView().environment(state).tint(Theme.accent).preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(state).tint(Theme.accent).preferredColorScheme(.dark)
        }
    }
}

@MainActor
@Observable
final class AppState {
    // Spaces (the focus — playable on desktop)
    var spaceQuery = ""
    var spaces: [HFSpace] = []
    var spacesLoading = false
    var openSpace: HFSpace?

    // Models
    var modelQuery = ""
    var models: [HubModel] = []
    var modelsLoading = false
    var pullingModel: String?

    // Yours (creator)
    var username: String?
    var mySpaces: [HFSpace] = []
    var myModels: [HubModel] = []

    // Run (Osaurus)
    var osaurusModels: [OsaurusModel] = []
    var selectedModel = ""
    var chat: [ChatMessage] = []
    var prompt = ""
    var generating = false
    var osaurusReachable = true
    var osaurusNote: String?

    // Credentials (Keychain)
    var hfToken = ""
    var osaurusKey = ""
    var settingsSavedNote: String?

    // Offline / Articles
    var offlineSpaces: Set<String> = []
    var downloadingSpace: String?
    var downloadNote: String?
    var articles: [Article] = []
    var articlesLoading = false
    private let articleService = ArticleService()

    private var hub: HubClient { HubClient(token: hfToken.isEmpty ? nil : hfToken) }
    private var osaurus: OsaurusClient { OsaurusClient(apiKey: osaurusKey.isEmpty ? nil : osaurusKey) }

    func bootstrap() async {
        hfToken = Keychain.get("hf_token") ?? ""
        osaurusKey = Keychain.get("osaurus_key") ?? ""
        await refreshOsaurus()
        await loadMine()
        // A friendly default: show the featured author's Spaces if empty.
        if spaces.isEmpty {
            spaceQuery = "PeetPedro"
            await searchSpaces()
        }
        refreshOffline()
        await loadArticles()
    }

    func searchSpaces() async {
        let q = spaceQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        spacesLoading = true; defer { spacesLoading = false }
        spaces = (try? await hub.searchSpaces(q)) ?? []
    }

    func searchModels() async {
        let q = modelQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        modelsLoading = true; defer { modelsLoading = false }
        models = (try? await hub.searchModels(q)) ?? []
    }

    func loadMine() async {
        guard let name = try? await hub.whoami() else { username = nil; return }
        username = name
        mySpaces = (try? await hub.spaces(author: name)) ?? []
        myModels = (try? await hub.models(author: name)) ?? []
    }

    func refreshOsaurus() async {
        do {
            osaurusModels = try await osaurus.models()
            osaurusReachable = true; osaurusNote = nil
            if selectedModel.isEmpty { selectedModel = osaurusModels.first?.id ?? "" }
        } catch {
            osaurusModels = []; osaurusReachable = false
            osaurusNote = "Osaurus not reachable on :1337 (set an API key in Settings if it requires one)."
        }
    }

    func pull(_ model: String) async {
        pullingModel = model
        defer { pullingModel = nil }
        osaurusNote = (try? await osaurus.pull(model)) ?? "pull failed"
        await refreshOsaurus()
    }

    /// Authoritative embed URL — prefer an offline snapshot, else the live host.
    func resolveHost(_ space: HFSpace) async -> URL {
        if let local = OfflineStore.spaceIndex(space.id) { return local }
        return await hub.spaceHost(space.id) ?? space.embedURL
    }

    func refreshOffline() {
        offlineSpaces = Set(spaces.filter { OfflineStore.isSpaceDownloaded($0.id) }.map(\.id))
    }

    func downloadSpaceOffline(_ space: HFSpace) async {
        downloadingSpace = space.id; downloadNote = nil
        defer { downloadingSpace = nil }
        do {
            let n = try await hub.downloadSpace(space.id)
            downloadNote = "\(space.name): \(n) files cached — playable offline"
            if OfflineStore.isSpaceDownloaded(space.id) { offlineSpaces.insert(space.id) }
        } catch {
            downloadNote = "download failed: \(error.localizedDescription)"
        }
    }

    func loadArticles() async {
        articlesLoading = true; defer { articlesLoading = false }
        articles = await articleService.fetch()
    }

    func cacheArticle(_ a: Article) async { await articleService.cache(a) }

    func articleURL(_ a: Article) -> URL {
        OfflineStore.isArticleCached(a.link) ? OfflineStore.articleFile(a.link) : (URL(string: a.link) ?? OfflineStore.articleFile(a.link))
    }
    func articleIsCached(_ a: Article) -> Bool { OfflineStore.isArticleCached(a.link) }

    func send() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !generating, !text.isEmpty, !selectedModel.isEmpty else { return }
        generating = true; defer { generating = false }
        chat.append(ChatMessage(role: "user", content: text))
        prompt = ""
        do {
            let reply = try await osaurus.chat(model: selectedModel, messages: chat)
            chat.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            chat.append(ChatMessage(role: "assistant", content: "⚠️ \(error.localizedDescription)"))
        }
    }

    func clearChat() {
        chat.removeAll()
    }

    func saveCredentials() {
        Keychain.set(hfToken, for: "hf_token")
        Keychain.set(osaurusKey, for: "osaurus_key")
        settingsSavedNote = "Saved to macOS Keychain ✓"
        Task {
            try? await Task.sleep(for: .seconds(3))
            settingsSavedNote = nil
        }
    }
}
