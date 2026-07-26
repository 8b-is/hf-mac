import Foundation

// MARK: - Hugging Face Hub

/// One model as returned by https://huggingface.co/api/models
struct HubModel: Identifiable, Decodable, Hashable, Sendable {
    let id: String            // "org/name"
    var likes: Int?
    var downloads: Int?
    var pipeline_tag: String?
    var library_name: String?
    var tags: [String]?
}

/// Read-only Hub client (search + your models). Token is optional; only needed
/// for private/your content. No SDK — just the public REST API, honestly.
struct HubClient: Sendable {
    var token: String?

    func search(_ query: String, limit: Int = 30) async throws -> [HubModel] {
        var comps = URLComponents(string: "https://huggingface.co/api/models")!
        comps.queryItems = [
            .init(name: "search", value: query),
            .init(name: "limit", value: String(limit)),
            .init(name: "sort", value: "downloads"),
            .init(name: "direction", value: "-1"),
        ]
        var req = URLRequest(url: comps.url!)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([HubModel].self, from: data)
    }
}

// MARK: - Osaurus (local, on-device inference — the engine)

struct OsaurusModel: Identifiable, Decodable, Hashable, Sendable { let id: String }
private struct OsaurusModelList: Decodable { let data: [OsaurusModel] }

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var role: String        // "user" | "assistant" | "system"
    var content: String
}

/// Talks to Osaurus's OpenAI-compatible local API (default localhost:1337).
/// The app never runs MLX itself — Osaurus owns weights + serving.
struct OsaurusClient: Sendable {
    var base = URL(string: "http://127.0.0.1:1337")!

    func models() async throws -> [OsaurusModel] {
        let (data, _) = try await URLSession.shared.data(from: base.appending(path: "/v1/models"))
        return try JSONDecoder().decode(OsaurusModelList.self, from: data).data
    }

    func chat(model: String, messages: [ChatMessage]) async throws -> String {
        var req = URLRequest(url: base.appending(path: "/v1/chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = obj?["choices"] as? [[String: Any]]
        let msg = choices?.first?["message"] as? [String: Any]
        return (msg?["content"] as? String) ?? "(no content returned by Osaurus)"
    }
}
