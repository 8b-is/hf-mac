import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case spaces = "Spaces"
    case articles = "Articles"
    case models = "Models"
    case run = "Run"
    case yours = "Yours"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .spaces: "gamecontroller"
        case .articles: "book"
        case .models: "cube.box"
        case .run: "bubble.left.and.text.bubble.right"
        case .yours: "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var tab: Tab = .spaces

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $tab) { t in
                Label(t.rawValue, systemImage: t.icon).tag(t)
            }
            .navigationTitle("hf.app")
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 6) {
                    Circle().fill(state.osaurusReachable ? .green : .orange).frame(width: 7, height: 7)
                    Text(state.username.map { "@\($0)" } ?? "not signed in")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }.padding(8)
            }
        } detail: {
            switch tab {
            case .spaces: SpacesView()
            case .articles: ArticlesView()
            case .models: ModelsView()
            case .run: RunView()
            case .yours: YoursView()
            }
        }
    }
}

// MARK: - Spaces (the focus — playable on desktop)

struct SpacesView: View {
    @Environment(AppState.self) private var state
    private let cols = [GridItem(.adaptive(minimum: 200), spacing: 14)]

    var body: some View {
        @Bindable var s = state
        NavigationStack {
            ScrollView {
                if state.spacesLoading { ProgressView().padding() }
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(state.spaces) { space in
                        NavigationLink(value: space) { SpaceCard(space: space) }
                            .buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationDestination(for: HFSpace.self) { SpacePlayerView(space: $0) }
            .navigationTitle("Spaces")
            .searchable(text: $s.spaceQuery, prompt: "Search Spaces (try: quantum, PeetPedro, gradio)")
            .onSubmit(of: .search) { Task { await state.searchSpaces() } }
            .overlay {
                if state.spaces.isEmpty && !state.spacesLoading {
                    ContentUnavailableView("Play a Space", systemImage: "gamecontroller",
                        description: Text("Search the Hub — Gradio demos, static apps, and your quantum games run right here on the desktop."))
                }
            }
        }
    }
}

struct SpaceCard: View {
    let space: HFSpace
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(space.emoji ?? "🚀").font(.system(size: 30))
            Text(space.name).font(.headline).lineLimit(1)
            Text(space.owner).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if let sdk = space.sdk { Label(sdk, systemImage: "square.stack.3d.up") }
                if let l = space.likes { Label(l.formatted(), systemImage: "heart") }
            }.font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}

struct SpacePlayerView: View {
    @Environment(AppState.self) private var state
    let space: HFSpace
    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                SpaceWebView(url: url).ignoresSafeArea(edges: .bottom)
            } else {
                ProgressView("Loading \(space.name)…")
            }
        }
        .navigationTitle(space.name)
        .toolbar {
            ToolbarItem {
                if state.downloadingSpace == space.id {
                    ProgressView().controlSize(.small)
                } else if OfflineStore.isSpaceDownloaded(space.id) {
                    Image(systemName: "checkmark.icloud").foregroundStyle(.green).help("Available offline")
                } else {
                    Button {
                        Task { await state.downloadSpaceOffline(space); url = await state.resolveHost(space) }
                    } label: { Image(systemName: "arrow.down.circle") }
                    .help("Download for offline play")
                }
            }
            ToolbarItem {
                Link(destination: URL(string: "https://huggingface.co/spaces/\(space.id)")!) {
                    Image(systemName: "safari")
                }.help("Open on huggingface.co")
            }
        }
        .task(id: space.id) { url = await state.resolveHost(space) }
    }
}

// MARK: - Articles (offline-first reader)

struct ArticlesView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        NavigationStack {
            List(state.articles) { a in
                NavigationLink(value: a) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(a.title).font(.headline)
                            if state.articleIsCached(a) {
                                Image(systemName: "checkmark.icloud").font(.caption).foregroundStyle(.green)
                            }
                        }
                        if !a.summary.isEmpty { Text(a.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        Text(a.source).font(.caption2).foregroundStyle(.tertiary)
                    }.padding(.vertical, 2)
                }
                .swipeActions { Button("Save") { Task { await state.cacheArticle(a) } } }
            }
            .navigationDestination(for: Article.self) { ArticleReaderView(article: $0) }
            .navigationTitle("Articles")
            .overlay {
                if state.articles.isEmpty {
                    if state.articlesLoading { ProgressView() }
                    else { ContentUnavailableView("Offline-first reading", systemImage: "book",
                        description: Text("Your pocoo essays — read on the plane. Open one and it's cached for offline.")) }
                }
            }
            .task { if state.articles.isEmpty { await state.loadArticles() } }
        }
    }
}

struct ArticleReaderView: View {
    @Environment(AppState.self) private var state
    let article: Article
    var body: some View {
        SpaceWebView(url: state.articleURL(article))
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(article.title)
            .toolbar {
                ToolbarItem {
                    Button { Task { await state.cacheArticle(article) } } label: {
                        Image(systemName: state.articleIsCached(article) ? "checkmark.icloud" : "arrow.down.circle")
                    }.help("Save for offline")
                }
            }
            .task { if !state.articleIsCached(article) { await state.cacheArticle(article) } }
    }
}

// MARK: - Models

struct ModelsView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        @Bindable var s = state
        List(state.models) { m in
            VStack(alignment: .leading, spacing: 4) {
                Text(m.id).font(.headline)
                HStack(spacing: 12) {
                    if let t = m.pipeline_tag { Label(t, systemImage: "tag") }
                    if let d = m.downloads { Label(d.formatted(), systemImage: "arrow.down.circle") }
                    if let l = m.likes { Label(l.formatted(), systemImage: "heart") }
                }.font(.caption).foregroundStyle(.secondary)
            }
            .contextMenu {
                Button("Pull into Osaurus") { Task { await state.pull(m.id) } }
                Link("Open on huggingface.co", destination: URL(string: "https://huggingface.co/\(m.id)")!)
            }
        }
        .searchable(text: $s.modelQuery, prompt: "Search models")
        .onSubmit(of: .search) { Task { await state.searchModels() } }
        .overlay { if state.models.isEmpty { ContentUnavailableView("Find a model", systemImage: "cube.box", description: Text("Search, then pull into Osaurus to run it locally.")) } }
    }
}

// MARK: - Run (Osaurus local chat)

struct RunView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        @Bindable var s = state
        VStack(spacing: 0) {
            HStack {
                Text("Local model")
                Picker("", selection: $s.selectedModel) { ForEach(state.osaurusModels) { Text($0.id).tag($0.id) } }
                    .labelsHidden().frame(maxWidth: 260)
                Button { Task { await state.refreshOsaurus() } } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                Text("on-device · Osaurus").font(.caption).foregroundStyle(.secondary)
            }.padding()
            if let n = state.osaurusNote { Text(n).font(.caption).foregroundStyle(.orange).padding(.horizontal) }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(state.chat) { m in
                        HStack {
                            if m.role == "user" { Spacer(minLength: 60) }
                            Text(m.content).textSelection(.enabled).padding(10)
                                .background(m.role == "user" ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 12))
                            if m.role != "user" { Spacer(minLength: 60) }
                        }
                    }
                    if state.generating { HStack { ProgressView().controlSize(.small); Text("thinking…").foregroundStyle(.secondary) } }
                }.padding()
            }
            Divider()
            HStack(alignment: .bottom) {
                TextField("Message the model…", text: $s.prompt, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...5)
                    .onSubmit { Task { await state.send() } }
                Button("Send") { Task { await state.send() } }.disabled(state.generating || state.selectedModel.isEmpty)
            }.padding()
        }
    }
}

// MARK: - Yours (creator)

struct YoursView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        if state.username == nil {
            ContentUnavailableView {
                Label("Sign in", systemImage: "person.crop.circle")
            } description: {
                Text("Add a Hugging Face token in Settings (⌘,) to see your Spaces and models here.")
            }
        } else {
            List {
                Section("Your Spaces (\(state.mySpaces.count))") {
                    ForEach(state.mySpaces) { sp in
                        NavigationLink { SpacePlayerView(space: sp) } label: {
                            Label("\(sp.emoji ?? "🚀")  \(sp.name)", systemImage: "")
                        }
                    }
                }
                Section("Your models (\(state.myModels.count))") {
                    ForEach(state.myModels) { m in
                        HStack { Text(m.id); Spacer(); if let d = m.downloads { Text(d.formatted()).foregroundStyle(.secondary) } }
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        @Bindable var s = state
        Form {
            Section("Hugging Face") {
                SecureField("Token (hf_…)", text: $s.hfToken)
                Text("Read access. Stored in your Keychain. Used for your Spaces/models and private content.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Osaurus (local inference)") {
                SecureField("API key (if Osaurus requires one)", text: $s.osaurusKey)
                Text("Only needed if Osaurus has auth enabled. Talks to localhost:1337.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Save") { state.saveCredentials(); Task { await state.loadMine(); await state.refreshOsaurus() } }
        }
        .padding(20).frame(width: 460)
    }
}

// MARK: - Menu-bar agent

struct MenuBarView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("hf.app").font(.headline)
                Spacer()
                Picker("", selection: $s.selectedModel) { ForEach(state.osaurusModels) { Text($0.id).tag($0.id) } }
                    .labelsHidden().frame(maxWidth: 150)
            }
            TextField("Quick prompt…", text: $s.prompt, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...4)
                .onSubmit { Task { await state.send() } }
            if let last = state.chat.last(where: { $0.role == "assistant" }) {
                ScrollView { Text(last.content).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 170)
            }
            HStack {
                Button("Send") { Task { await state.send() } }.disabled(state.generating || state.selectedModel.isEmpty)
                Spacer()
                if state.generating { ProgressView().controlSize(.small) }
            }
        }
        .padding(12).frame(width: 320)
    }
}
