import SwiftUI

// hf.app — a native macOS Hugging Face client. Browse the Hub, pull models into
// Osaurus, run + chat locally on Apple Silicon. Full window + a menu-bar agent.
@main
struct HFMacApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .task { await state.refreshOsaurus() }
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1040, height: 700)

        MenuBarExtra("hf", systemImage: "brain.head.profile") {
            MenuBarView().environment(state)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The whole app's observable state. MainActor-isolated; the network clients are
/// plain Sendable structs called with async/await.
@MainActor
@Observable
final class AppState {
    // Browse (Hugging Face)
    var query = ""
    var results: [HubModel] = []
    var searching = false
    var searchError: String?

    // Run (Osaurus, local)
    var osaurusModels: [OsaurusModel] = []
    var selectedModel = ""
    var chat: [ChatMessage] = []
    var prompt = ""
    var generating = false
    var osaurusReachable = true

    private let hub = HubClient()
    private let osaurus = OsaurusClient()

    func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        searching = true
        searchError = nil
        defer { searching = false }
        do { results = try await hub.search(q) }
        catch { searchError = error.localizedDescription }
    }

    func refreshOsaurus() async {
        do {
            osaurusModels = try await osaurus.models()
            osaurusReachable = true
            if selectedModel.isEmpty { selectedModel = osaurusModels.first?.id ?? "" }
        } catch {
            osaurusModels = []
            osaurusReachable = false
        }
    }

    func send() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !selectedModel.isEmpty else { return }
        chat.append(ChatMessage(role: "user", content: text))
        prompt = ""
        generating = true
        defer { generating = false }
        do {
            let reply = try await osaurus.chat(model: selectedModel, messages: chat)
            chat.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            chat.append(ChatMessage(role: "assistant", content: "⚠️ \(error.localizedDescription)"))
        }
    }
}
