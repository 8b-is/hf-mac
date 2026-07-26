import Foundation

// MARK: - Hugging Face Hub (models + spaces)

struct HubModel: Identifiable, Decodable, Hashable, Sendable {
    let id: String
    var likes: Int?
    var downloads: Int?
    var pipeline_tag: String?
    var library_name: String?
}

/// A Hugging Face Space. `id` is "owner/name"; the live app is served at
/// https://<owner>-<name>.hf.space — which is exactly what we embed to make it
/// playable on the desktop (your quantum games, and any Gradio/static Space).
struct HFSpace: Identifiable, Decodable, Hashable, Sendable {
    let id: String
    var likes: Int?
    var sdk: String?          // "gradio" | "streamlit" | "static" | "docker"
    var emoji: String?
    var host: String?         // authoritative embed host (from api/spaces/<id>); static → *.static.hf.space
    var subdomain: String?

    var owner: String { id.split(separator: "/").first.map(String.init) ?? id }
    var name: String { id.split(separator: "/").last.map(String.init) ?? id }

    /// Best embed URL from what we already have. Prefer the API `host` (correct
    /// for static vs gradio); else the subdomain; else a plain guess. The player
    /// resolves the authoritative host via `HubClient.spaceHost` before loading.
    var embedURL: URL {
        if let host, let u = URL(string: host) { return u }
        if let subdomain, !subdomain.isEmpty { return URL(string: "https://\(subdomain).hf.space")! }
        let guess = "\(owner)-\(name)".lowercased()
        return URL(string: "https://\(guess).hf.space")!
    }
}

struct HubClient: Sendable {
    var token: String?

    private func authed(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token, !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return req
    }

    func searchModels(_ query: String, limit: Int = 30) async throws -> [HubModel] {
        var c = URLComponents(string: "https://huggingface.co/api/models")!
        c.queryItems = [.init(name: "search", value: query), .init(name: "limit", value: String(limit)),
                        .init(name: "sort", value: "downloads"), .init(name: "direction", value: "-1")]
        let (data, _) = try await URLSession.shared.data(for: authed(c.url!))
        return try JSONDecoder().decode([HubModel].self, from: data)
    }

    func searchSpaces(_ query: String, limit: Int = 40) async throws -> [HFSpace] {
        var c = URLComponents(string: "https://huggingface.co/api/spaces")!
        c.queryItems = [.init(name: "search", value: query), .init(name: "limit", value: String(limit)),
                        .init(name: "sort", value: "likes"), .init(name: "direction", value: "-1")]
        let (data, _) = try await URLSession.shared.data(for: authed(c.url!))
        return try JSONDecoder().decode([HFSpace].self, from: data)
    }

    func spaces(author: String, limit: Int = 60) async throws -> [HFSpace] {
        var c = URLComponents(string: "https://huggingface.co/api/spaces")!
        c.queryItems = [.init(name: "author", value: author), .init(name: "limit", value: String(limit))]
        let (data, _) = try await URLSession.shared.data(for: authed(c.url!))
        return try JSONDecoder().decode([HFSpace].self, from: data)
    }

    func models(author: String, limit: Int = 60) async throws -> [HubModel] {
        var c = URLComponents(string: "https://huggingface.co/api/models")!
        c.queryItems = [.init(name: "author", value: author), .init(name: "limit", value: String(limit)),
                        .init(name: "sort", value: "downloads"), .init(name: "direction", value: "-1")]
        let (data, _) = try await URLSession.shared.data(for: authed(c.url!))
        return try JSONDecoder().decode([HubModel].self, from: data)
    }

    /// Fetch a Space's authoritative embed host (correct for static vs gradio).
    func spaceHost(_ id: String) async -> URL? {
        guard let (data, _) = try? await URLSession.shared.data(for: authed(URL(string: "https://huggingface.co/api/spaces/\(id)")!)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let host = obj["host"] as? String, let u = URL(string: host) { return u }
        if let sub = obj["subdomain"] as? String { return URL(string: "https://\(sub).hf.space") }
        return nil
    }

    /// token -> your username (nil if no/invalid token).
    func whoami() async throws -> String? {
        guard token?.isEmpty == false else { return nil }
        let (data, resp) = try await URLSession.shared.data(for: authed(URL(string: "https://huggingface.co/api/whoami-v2")!))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["name"] as? String
    }
}

// MARK: - Osaurus (local inference)

struct OsaurusModel: Identifiable, Decodable, Hashable, Sendable { let id: String }
private struct OsaurusModelList: Decodable { let data: [OsaurusModel] }

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var role: String
    var content: String
}

/// Osaurus local API (localhost:1337). OpenAI-compatible for chat + models,
/// Ollama-compatible /api/pull for pulling. API key optional (sent if set).
struct OsaurusClient: Sendable {
    var base = URL(string: "http://127.0.0.1:1337")!
    var apiKey: String?

    private func req(_ path: String, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: base.appending(path: path))
        r.httpMethod = method
        if let apiKey, !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        return r
    }

    func models() async throws -> [OsaurusModel] {
        let (data, _) = try await URLSession.shared.data(for: req("/v1/models"))
        return try JSONDecoder().decode(OsaurusModelList.self, from: data).data
    }

    func chat(model: String, messages: [ChatMessage]) async throws -> String {
        var r = req("/v1/chat/completions", method: "POST")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
        ])
        let (data, _) = try await URLSession.shared.data(for: r)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = obj?["choices"] as? [[String: Any]]
        let msg = choices?.first?["message"] as? [String: Any]
        return (msg?["content"] as? String) ?? "(no content)"
    }

    /// Best-effort Ollama-style pull. Returns the HTTP status line for honesty.
    func pull(_ model: String) async throws -> String {
        var r = req("/api/pull", method: "POST")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": false])
        let (_, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return code == 200 ? "pulling \(model)…" : "Osaurus returned HTTP \(code) (needs an API key? set it in Settings)"
    }
}
