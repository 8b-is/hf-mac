import Foundation

/// Minimal, opt-in Langfuse tracer (POST {host}/api/public/trace).
///
/// The app's creed is zero telemetry: nothing leaves the machine unless the
/// user explicitly sets LANGFUSE_HOST, LANGFUSE_PUBLIC_KEY and
/// LANGFUSE_SECRET_KEY in the environment. When disabled every method is a
/// no-op and no network request is ever constructed.
enum LangfuseTracer: Sendable {
    /// True only when all three LANGFUSE_* env vars are set and non-empty.
    static var isEnabled: Bool {
        !(env["LANGFUSE_HOST"] ?? "").isEmpty
            && !(env["LANGFUSE_PUBLIC_KEY"] ?? "").isEmpty
            && !(env["LANGFUSE_SECRET_KEY"] ?? "").isEmpty
    }

    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    /// Record a chat completion as a Langfuse trace. Fire-and-forget: the
    /// POST runs on a detached task, never blocks or fails the caller, and
    /// every error is swallowed. No-op when Langfuse is not enabled.
    static func traceChat(
        model: String,
        inputTokens: Int?,
        output: String?,
        durationMs: Double,
        errorDescription: String?
    ) async {
        // Opt-in gating: without all three env vars no request is built.
        guard isEnabled,
              let host = env["LANGFUSE_HOST"],
              let publicKey = env["LANGFUSE_PUBLIC_KEY"],
              let secretKey = env["LANGFUSE_SECRET_KEY"]
        else { return }

        let end = Date()
        let start = end.addingTimeInterval(-durationMs / 1000)
        var metadata: [String: Any] = [:]
        if let inputTokens { metadata["inputTokens"] = inputTokens }
        if let errorDescription { metadata["error"] = errorDescription }

        let observation: [String: Any] = [
            "name": "chat",
            "type": "GENERATION",
            "model": model,
            "startTime": iso8601(start),
            "endTime": iso8601(end),
            "level": errorDescription == nil ? "DEFAULT" : "ERROR",
            "metadata": metadata,
        ]
        let payload: [String: Any] = [
            "name": "chat",
            "timestamp": iso8601(end),
            "output": output ?? "",
            "metadata": metadata,
            "observations": [observation],
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let url = URL(string: host.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/public/trace")
        else { return }

        let credentials = "\(publicKey):\(secretKey)".data(using: .utf8)!.base64EncodedString()
        Task.detached {
            var r = URLRequest(url: url)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            r.httpBody = body
            _ = try? await URLSession.shared.data(for: r)
        }
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
