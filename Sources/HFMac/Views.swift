import SwiftUI

// MARK: - Sidebar / shell

enum Tab: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case run = "Run"
    case yours = "Your models"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .browse: "magnifyingglass"
        case .run: "bubble.left.and.text.bubble.right"
        case .yours: "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var tab: Tab = .browse

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $tab) { t in
                Label(t.rawValue, systemImage: t.icon).tag(t)
            }
            .navigationTitle("hf.app")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.osaurusReachable ? .green : .orange)
                        .frame(width: 7, height: 7)
                    Text(state.osaurusReachable ? "Osaurus · 1337" : "Osaurus offline")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(8)
            }
        } detail: {
            switch tab {
            case .browse: BrowseView()
            case .run: RunView()
            case .yours: CreatorView()
            }
        }
    }
}

// MARK: - Browse (Hugging Face)

struct BrowseView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Search Hugging Face models…", text: $s.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await state.search() } }
                Button("Search") { Task { await state.search() } }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding()

            if state.searching { ProgressView().padding(.horizontal) }
            if let e = state.searchError {
                Label(e, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).padding(.horizontal)
            }

            if state.results.isEmpty && !state.searching {
                ContentUnavailableView("Find a model",
                    systemImage: "magnifyingglass",
                    description: Text("Search the Hub, then open one in Run to chat with it locally through Osaurus."))
            } else {
                List(state.results) { m in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(m.id).font(.headline)
                        HStack(spacing: 14) {
                            if let t = m.pipeline_tag { Label(t, systemImage: "tag") }
                            if let lib = m.library_name { Label(lib, systemImage: "shippingbox") }
                            if let d = m.downloads { Label(d.formatted(), systemImage: "arrow.down.circle") }
                            if let l = m.likes { Label(l.formatted(), systemImage: "heart") }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                    .contextMenu {
                        Link("Open on huggingface.co",
                             destination: URL(string: "https://huggingface.co/\(m.id)")!)
                    }
                }
            }
        }
    }
}

// MARK: - Run (local chat via Osaurus)

struct RunView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var s = state
        VStack(spacing: 0) {
            HStack {
                Text("Local model")
                Picker("", selection: $s.selectedModel) {
                    ForEach(state.osaurusModels) { Text($0.id).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                Button { Task { await state.refreshOsaurus() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Osaurus models")
                Spacer()
                Text("on-device · Osaurus").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(state.chat) { m in
                        HStack {
                            if m.role == "user" { Spacer(minLength: 60) }
                            Text(m.content)
                                .textSelection(.enabled)
                                .padding(10)
                                .background(m.role == "user"
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.gray.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            if m.role != "user" { Spacer(minLength: 60) }
                        }
                    }
                    if state.generating {
                        HStack { ProgressView().controlSize(.small); Text("thinking…").foregroundStyle(.secondary) }
                    }
                }
                .padding()
            }

            Divider()
            HStack(alignment: .bottom) {
                TextField("Message the model…", text: $s.prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit { Task { await state.send() } }
                Button("Send") { Task { await state.send() } }
                    .disabled(state.generating || state.selectedModel.isEmpty)
            }
            .padding()
        }
        .overlay {
            if state.osaurusModels.isEmpty {
                ContentUnavailableView("No local models",
                    systemImage: "cpu",
                    description: Text("Pull a model in Osaurus, then refresh. Its OpenAI-compatible API on :1337 is what this tab talks to."))
            }
        }
    }
}

// MARK: - Your models (creator — next phase)

struct CreatorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Your models", systemImage: "person.crop.circle")
        } description: {
            Text("Sign in with an HF token to see your models, downloads over time, and Space build status. (Creator tab — next phase.)")
        }
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
                Picker("", selection: $s.selectedModel) {
                    ForEach(state.osaurusModels) { Text($0.id).tag($0.id) }
                }
                .labelsHidden().frame(maxWidth: 150)
            }

            TextField("Quick prompt…", text: $s.prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit { Task { await state.send() } }

            if let last = state.chat.last(where: { $0.role == "assistant" }) {
                ScrollView {
                    Text(last.content).font(.callout).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 170)
            }

            HStack {
                Button("Send") { Task { await state.send() } }
                    .disabled(state.generating || state.selectedModel.isEmpty)
                Spacer()
                if state.generating { ProgressView().controlSize(.small) }
                Text(state.osaurusReachable ? "local" : "offline")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320)
        .task { if state.osaurusModels.isEmpty { await state.refreshOsaurus() } }
    }
}
