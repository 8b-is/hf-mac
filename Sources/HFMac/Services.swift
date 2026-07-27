import Foundation

// MARK: - Errors

enum HubError: LocalizedError, Sendable {
    case invalidURL
    case networkError(HTTPURLResponse)
    case decodeError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid Hugging Face API URL."
        case .networkError(let resp): "Hugging Face API returned HTTP status \(resp.statusCode)."
        case .decodeError(let err): "Failed to parse Hugging Face data: \(err.localizedDescription)"
        }
    }
}

enum OsaurusError: LocalizedError, Sendable {
    case unreachable(String)
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unreachable(let msg): "Osaurus engine unreachable: \(msg)"
        case .httpError(let code): "Osaurus HTTP \(code) error."
        case .invalidResponse: "Invalid response from local model server."
        }
    }
}

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
        guard let url = c.url else { throw HubError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(for: authed(url))
        guard let httpResp = resp as? HTTPURLResponse else { throw HubError.invalidURL }
        guard httpResp.statusCode == 200 else { throw HubError.networkError(httpResp) }
        do {
            return try JSONDecoder().decode([HubModel].self, from: data)
        } catch {
            throw HubError.decodeError(error)
        }
    }

    func searchSpaces(_ query: String, limit: Int = 40) async throws -> [HFSpace] {
        var c = URLComponents(string: "https://huggingface.co/api/spaces")!
        c.queryItems = [.init(name: "search", value: query), .init(name: "limit", value: String(limit)),
                        .init(name: "sort", value: "likes"), .init(name: "direction", value: "-1")]
        guard let url = c.url else { throw HubError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(for: authed(url))
        guard let httpResp = resp as? HTTPURLResponse else { throw HubError.invalidURL }
        guard httpResp.statusCode == 200 else { throw HubError.networkError(httpResp) }
        do {
            return try JSONDecoder().decode([HFSpace].self, from: data)
        } catch {
            throw HubError.decodeError(error)
        }
    }

    func spaces(author: String, limit: Int = 60) async throws -> [HFSpace] {
        var c = URLComponents(string: "https://huggingface.co/api/spaces")!
        c.queryItems = [.init(name: "author", value: author), .init(name: "limit", value: String(limit))]
        guard let url = c.url else { throw HubError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(for: authed(url))
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            if let httpResp = resp as? HTTPURLResponse { throw HubError.networkError(httpResp) }
            throw HubError.invalidURL
        }
        return try JSONDecoder().decode([HFSpace].self, from: data)
    }

    func models(author: String, limit: Int = 60) async throws -> [HubModel] {
        var c = URLComponents(string: "https://huggingface.co/api/models")!
        c.queryItems = [.init(name: "author", value: author), .init(name: "limit", value: String(limit)),
                        .init(name: "sort", value: "downloads"), .init(name: "direction", value: "-1")]
        guard let url = c.url else { throw HubError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(for: authed(url))
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            if let httpResp = resp as? HTTPURLResponse { throw HubError.networkError(httpResp) }
            throw HubError.invalidURL
        }
        return try JSONDecoder().decode([HubModel].self, from: data)
    }

    /// Fetch a Space's authoritative embed host (correct for static vs gradio).
    func spaceHost(_ id: String) async -> URL? {
        guard let (data, resp) = try? await URLSession.shared.data(for: authed(URL(string: "https://huggingface.co/api/spaces/\(id)")!)),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let host = obj["host"] as? String, let u = URL(string: host) { return u }
        if let sub = obj["subdomain"] as? String { return URL(string: "https://\(sub).hf.space") }
        return nil
    }

    /// List a Space's files (for offline snapshot). Static spaces = plain files.
    func spaceFiles(_ id: String) async throws -> [String] {
        guard let url = URL(string: "https://huggingface.co/api/spaces/\(id)/tree/main?recursive=true") else { return [] }
        let (data, resp) = try await URLSession.shared.data(for: authed(url))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return arr.compactMap { ($0["type"] as? String) == "file" ? $0["path"] as? String : nil }
    }

    /// Download a Space's full file tree into the offline store → playable offline.
    /// Returns the number of files written. (Best for `static` Spaces.)
    func downloadSpace(_ id: String) async throws -> Int {
        let files = try await spaceFiles(id)
        let dir = OfflineStore.spaceDir(id)
        var written = 0
        for path in files {
            guard let safePath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let src = URL(string: "https://huggingface.co/spaces/\(id)/resolve/main/\(safePath)") else { continue }
            let (data, resp) = try await URLSession.shared.data(for: authed(src))
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { continue }
            try OfflineStore.write(data, to: dir.appending(path: path))
            written += 1
        }
        return written
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
        let (data, resp) = try await URLSession.shared.data(for: req("/v1/models"))
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 500
            throw OsaurusError.httpError(code)
        }
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
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let httpResp = resp as? HTTPURLResponse else { throw OsaurusError.invalidResponse }
        guard httpResp.statusCode == 200 else { throw OsaurusError.httpError(httpResp.statusCode) }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = obj?["choices"] as? [[String: Any]]
        let msg = choices?.first?["message"] as? [String: Any]
        return (msg?["content"] as? String) ?? "(no content)"
    }

    /// Streaming chat — yields content deltas as the model generates them
    /// (OpenAI-compatible SSE). Lets the UI fill token-by-token at the model's
    /// real tokens/sec instead of blocking on the whole reply.
    func chatStream(model: String, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var r = req("/v1/chat/completions", method: "POST")
                    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": model,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true,
                    ])
                    let (bytes, resp) = try await URLSession.shared.bytes(for: r)
                    guard let http = resp as? HTTPURLResponse else { throw OsaurusError.invalidResponse }
                    guard http.statusCode == 200 else { throw OsaurusError.httpError(http.statusCode) }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let d = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let piece = delta["content"] as? String, !piece.isEmpty
                        else { continue }
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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

// MARK: - Articles (offline-first reader)

struct Article: Identifiable, Hashable, Sendable {
    let title: String
    let link: String
    let summary: String
    var source: String
    var id: String { link }
}

/// Aggregates article feeds and caches their HTML for offline reading. Uses each
/// site's `llms.txt` (a clean `- [title](url): desc` markdown list) rather than
/// XML — simpler and robust. Starts with your pocoo essays; add sources freely.
struct ArticleService: Sendable {
    static let sources: [(name: String, llms: URL)] = [
        ("pocoo", URL(string: "https://pocoo.vaked.dev/llms.txt")!),
        ("8b public docs", URL(string: "https://8b.is/llms.txt")!),
        ("entheai docs", URL(string: "https://entheai.com/llms.txt")!),
        ("vaked docs", URL(string: "https://vaked.dev/llms.txt")!),
    ]

    func fetch() async -> [Article] {
        var out: [Article] = []
        for src in Self.sources {
            guard let (data, resp) = try? await URLSession.shared.data(from: src.llms),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let text = String(data: data, encoding: .utf8) else { continue }
            for raw in text.split(separator: "\n") {
                let line = String(raw)
                guard line.hasPrefix("- ["),
                      let t0 = line.firstIndex(of: "["), let t1 = line.firstIndex(of: "]"),
                      let u0 = line.firstIndex(of: "("), let u1 = line.firstIndex(of: ")"),
                      line.index(after: t0) < t1, line.index(after: u0) < u1 else { continue }
                let title = String(line[line.index(after: t0)..<t1])
                let link = String(line[line.index(after: u0)..<u1])
                guard link.contains("/posts/") else { continue }
                var summary = ""
                if let colon = line.range(of: "): ") { summary = String(line[colon.upperBound...]) }
                out.append(Article(title: title, link: link, summary: summary, source: src.name))
            }
        }
        return out
    }

    /// Download + cache an article's HTML for offline reading. Returns the local file.
    @discardableResult
    func cache(_ article: Article) async -> URL? {
        guard let url = URL(string: article.link),
              let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let dest = OfflineStore.articleFile(article.link)
        try? OfflineStore.write(data, to: dest)
        return dest
    }
}

// MARK: - ayeOS (ternary inference daemon — MEMNET protocol)

/// Error types for ayeOS MEMNET communication.
enum AyeosError: LocalizedError, Sendable {
    case unreachable(String)
    case invalidResponse
    case protocolError(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let msg): "ayeOS daemon unreachable: \(msg)"
        case .invalidResponse: "Invalid response from ayeOS MEMNET."
        case .protocolError(let msg): "ayeOS protocol error: \(msg)"
        }
    }
}

/// MEMNET capsule response from ayeOS.
struct AyeosCapsule: Decodable, Sendable {
    let capsule_id: String
    let payload_type: String
    let relevance_score: Float
    let timestamp: UInt64
}

/// ayeOS daemon client — MEMNET TCP protocol on :9876.
/// Commands: ping, stats, capsule, get matrix.
struct AyeosClient: Sendable {
    var host = "127.0.0.1"
    var port: UInt16 = 9876

    /// Send a text command over TCP and return the response.
    func sendCommand(_ cmd: String) async throws -> String {
        var response = ""
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                var readStream: Unmanaged<CFReadStream>?
                var writeStream: Unmanaged<CFWriteStream>?
                CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readStream, &writeStream)
                guard let read = readStream?.takeRetainedValue(),
                      let write = writeStream?.takeRetainedValue() else {
                    c.resume(throwing: AyeosError.unreachable("stream creation failed"))
                    return
                }
                let data = (cmd + "\n").data(using: .utf8)!
                let wData = data as CFData
                CFWriteStreamOpen(write)
                CFWriteStreamWrite(write, CFDataGetBytePtr(wData), CFDataGetLength(wData))
                CFWriteStreamClose(write)

                CFReadStreamOpen(read)
                var buf = [UInt8](repeating: 0, count: 4096)
                let n = CFReadStreamRead(read, &buf, 4096)
                if n > 0 {
                    response = String(bytes: buf[..<n], encoding: .utf8) ?? ""
                }
                CFReadStreamClose(read)
                c.resume()
            }
        }
        return response
    }

    /// Check if the ayeOS daemon is reachable.
    var isReachable: Bool {
        get async {
            (try? await sendCommand("ping"))?.contains("pong") ?? false
        }
    }

    /// Fetch the MEMNET capsule (ternary matrix metadata).
    func capsule() async throws -> AyeosCapsule {
        let resp = try await sendCommand("capsule")
        guard let data = resp.data(using: .utf8),
              let capsule = try? JSONDecoder().decode(AyeosCapsule.self, from: data)
        else { throw AyeosError.invalidResponse }
        return capsule
    }

    /// Fetch system stats.
    func stats() async throws -> String {
        try await sendCommand("stats")
    }
}

// MARK: - entheai (agent subprocess)

/// Error types for entheai agent communication.
enum EntheaiError: LocalizedError, Sendable {
    case notFound(String)
    case executionError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notFound(let path): "entheai binary not found at \(path)"
        case .executionError(let msg): "entheai error: \(msg)"
        case .timeout: "entheai agent timed out"
        }
    }
}

/// entheai agent result.
struct EntheaiResult: Decodable, Sendable {
    let output: String
    let tool_calls: Int?
    let duration_ms: UInt64?
}

/// Client that runs entheai as a subprocess for agent tasks.
/// Communicates via CLI args (one-shot mode) or stdin/stdout JSON-RPC.
struct EntheaiClient: Sendable {
    var binaryPath: String = "/usr/local/bin/entheai"
    var timeoutSecs: UInt64 = 120

    /// Run entheai with a prompt and optional flags.
    func run(prompt: String, model: String? = nil, yolo: Bool = false) async throws -> EntheaiResult {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw EntheaiError.notFound(binaryPath)
        }
        var args = ["--prompt", prompt]
        if let model { args += ["--model", model] }
        if yolo { args += ["--yolo"] }

        let capturedArgs = args  // avoid Sendable capture warning
        return try await withCheckedThrowingContinuation { c in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binaryPath)
                process.arguments = capturedArgs

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    let deadline = DispatchTime.now() + .seconds(Int(timeoutSecs))
                    DispatchQueue.global().asyncAfter(deadline: deadline) {
                        if process.isRunning {
                            process.terminate()
                            c.resume(throwing: EntheaiError.timeout)
                        }
                    }
                    process.waitUntilExit()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let error = String(data: errData, encoding: .utf8) ?? ""
                    if !error.isEmpty {
                        c.resume(returning: EntheaiResult(output: output + "\n(stderr: \(error))", tool_calls: nil, duration_ms: nil))
                    } else {
                        c.resume(returning: EntheaiResult(output: output, tool_calls: nil, duration_ms: nil))
                    }
                } catch {
                    c.resume(throwing: EntheaiError.executionError(error.localizedDescription))
                }
            }
        }
    }

    /// Run entheai with fan-out decomposition.
    func fanout(prompt: String) async throws -> EntheaiResult {
        try await run(prompt: prompt, yolo: true)
    }
}

// MARK: - Process lifecycle manager

/// Manages lifecycle of companion subprocesses (entheai, ayeOS).
/// Launches, monitors, and reports availability to the UI.
@MainActor
@Observable
final class ProcessManager {
    /// Whether entheai agent binary is available.
    var entheaiAvailable = false
    /// Whether ayeOS daemon binary is available.
    var ayeosAvailable = false
    /// Whether ayeOS is reachable on its TCP port.
    var ayeosReachable = false
    /// Status notes for the UI.
    var note: String?

    private let ayeosClient = AyeosClient()
    private let entheaiClient: EntheaiClient

    init(entheaiPath: String = "/usr/local/bin/entheai") {
        self.entheaiClient = EntheaiClient(binaryPath: entheaiPath)
        checkAvailability()
    }

    /// Check which binaries are available on disk.
    func checkAvailability() {
        entheaiAvailable = FileManager.default.isExecutableFile(atPath: entheaiClient.binaryPath)
        ayeosAvailable = FileManager.default.isExecutableFile(atPath: "/usr/local/bin/ayeosd")
    }

    /// Check ayeOS reachability over MEMNET.
    func checkAyeosReachability() async {
        ayeosReachable = await ayeosClient.isReachable
    }

    /// Run entheai agent with a prompt.
    func runEntheai(prompt: String, model: String? = nil) async -> String? {
        guard entheaiAvailable else { note = "entheai binary not found"; return nil }
        do {
            let result = try await entheaiClient.run(prompt: prompt, model: model)
            return result.output
        } catch {
            note = "entheai: \(error.localizedDescription)"
            return nil
        }
    }

    /// Run entheai with fan-out decomposition.
    func fanout(prompt: String) async -> String? {
        guard entheaiAvailable else { note = "entheai binary not found"; return nil }
        do {
            let result = try await entheaiClient.fanout(prompt: prompt)
            return result.output
        } catch {
            note = "entheai fanout: \(error.localizedDescription)"
            return nil
        }
    }

    /// Fetch ayeOS genesis capsule metadata.
    func ayeosCapsule() async -> AyeosCapsule? {
        guard ayeosReachable else { return nil }
        return try? await ayeosClient.capsule()
    }
}
