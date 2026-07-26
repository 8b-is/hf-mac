import Foundation

/// Mixture of Experts (MoE) Optimizer layer for hf.app.
/// Analyzes prompt intent, routes queries to domain-specialized local models,
/// and applies expert system prompts for maximum Apple Silicon throughput.
enum ExpertDomain: String, CaseIterable, Identifiable, Sendable {
    case general = "General Expert"
    case code = "Code Expert"
    case reasoning = "Reasoning & Math Expert"
    case summary = "Summarization Expert"
    case creative = "Creative Writing Expert"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: "brain"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .reasoning: "function"
        case .summary: "doc.text"
        case .creative: "paintpalette"
        }
    }

    var systemPrompt: String {
        switch self {
        case .general:
            "You are a helpful, precise, and concise AI assistant running locally on Apple Silicon."
        case .code:
            "You are an expert software engineer. Provide clean, efficient, production-ready code with minimal explanation."
        case .reasoning:
            "You are a rigorous mathematical and logical reasoning expert. Break down complex problems step-by-step before stating the final conclusion."
        case .summary:
            "You are an expert summarizer. Extract key actionable takeaways, bullet points, and core insights concisely."
        case .creative:
            "You are a creative writer and storyteller. Craft vivid, compelling, and engaging text with rich vocabulary."
        }
    }
}

struct MoERouteResult: Sendable {
    let domain: ExpertDomain
    let recommendedModelID: String?
    let formattedMessages: [ChatMessage]
}

struct MoEOptimizer: Sendable {
    /// Classifies a prompt into the optimal ExpertDomain based on keywords and patterns.
    static func classify(_ prompt: String) -> ExpertDomain {
        let p = prompt.lowercased()
        if p.contains("code") || p.contains("func ") || p.contains("def ") || p.contains("class ") ||
           p.contains("import ") || p.contains("const ") || p.contains("bug") || p.contains("fix") ||
           p.contains("rust") || p.contains("swift") || p.contains("python") || p.contains("html") ||
           p.contains("```") {
            return .code
        }
        if p.contains("solve") || p.contains("math") || p.contains("calculate") || p.contains("equation") ||
           p.contains("reason") || p.contains("proof") || p.contains("logic") || p.contains("why does") {
            return .reasoning
        }
        if p.contains("summarize") || p.contains("summary") || p.contains("tl;dr") || p.contains("tldr") ||
           p.contains("bullet points") || p.contains("key takeaways") {
            return .summary
        }
        if p.contains("story") || p.contains("poem") || p.contains("write a") || p.contains("novel") ||
           p.contains("essay") || p.contains("draft an email") {
            return .creative
        }
        return .general
    }

    /// Selects the best available model ID matching the expert domain.
    static func selectBestModel(for domain: ExpertDomain, availableModels: [OsaurusModel]) -> String? {
        guard !availableModels.isEmpty else { return nil }
        let ids = availableModels.map { $0.id.lowercased() }

        switch domain {
        case .code:
            if let idx = ids.firstIndex(where: { $0.contains("coder") || $0.contains("code") || $0.contains("deepseek-coder") }) {
                return availableModels[idx].id
            }
        case .reasoning:
            if let idx = ids.firstIndex(where: { $0.contains("r1") || $0.contains("reason") || $0.contains("math") || $0.contains("qwq") }) {
                return availableModels[idx].id
            }
        case .summary, .creative, .general:
            break
        }
        return availableModels.first?.id
    }

    /// Prepares optimized chat messages with expert system instructions.
    static func optimize(prompt: String, chatHistory: [ChatMessage], availableModels: [OsaurusModel], forceDomain: ExpertDomain? = nil) -> MoERouteResult {
        let domain = forceDomain ?? classify(prompt)
        let model = selectBestModel(for: domain, availableModels: availableModels)

        var messages: [ChatMessage] = []
        if !chatHistory.contains(where: { $0.role == "system" }) {
            messages.append(ChatMessage(role: "system", content: domain.systemPrompt))
        }
        messages.append(contentsOf: chatHistory)

        return MoERouteResult(domain: domain, recommendedModelID: model, formattedMessages: messages)
    }
}
