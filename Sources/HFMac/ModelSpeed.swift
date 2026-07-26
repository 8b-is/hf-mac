import Foundation

/// Classifies a Hub model by its on-device inference speed on Apple Silicon,
/// inferred from its id + library. Fewer bits per weight = faster: local
/// inference is memory-bandwidth bound, so a 4-bit model moves ~4× less data
/// than fp16 and runs ~2–4× faster in Osaurus.
///
/// The frontier is **8b's MLX-QUANT** — native BitNet b1.58 *ternary* kernels
/// (~1.58 bits, the rivaquant lineage): the fastest of all, once an engine
/// built on MLX-QUANT serves them. See ROADMAP.
enum ModelSpeed: Int, Sendable, Comparable {
    case unknown = 0
    case full    = 1   // fp16 / bf16 / fp32 — full precision, slowest on-device
    case quant   = 2   // GGUF / AWQ / GPTQ / bitsandbytes — smaller, faster
    case mlx4bit = 3   // MLX 4-bit — fast, runs great in Osaurus today
    case ternary = 4   // BitNet b1.58 (MLX-QUANT / rivaquant) — fastest

    static func < (a: ModelSpeed, b: ModelSpeed) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .ternary: "🜂 ternary · fastest"
        case .mlx4bit: "⚡ MLX 4-bit · fast"
        case .quant:   "◆ quantized"
        case .full:    "full precision · slower"
        case .unknown: ""
        }
    }
    var isFast: Bool { self >= .quant }

    /// Best-effort classification from the model id + `library_name`.
    static func of(_ id: String, library: String? = nil) -> ModelSpeed {
        let s = id.lowercased()
        let lib = (library ?? "").lowercased()
        if s.contains("bitnet") || s.contains("ternary") || s.contains("1.58") ||
           s.contains("1bit") || s.contains("1-bit") || s.contains("rivaquant") { return .ternary }
        let has4bit = s.contains("4bit") || s.contains("4-bit") || s.contains("q4") || s.contains("int4")
        if lib == "mlx" || s.contains("mlx") { return has4bit ? .mlx4bit : .quant }
        if has4bit || s.contains("gguf") || s.contains("awq") || s.contains("gptq") ||
           s.contains("int8") || s.contains("q8") || s.contains("bnb") || s.contains("gptq") { return .quant }
        if s.contains("fp16") || s.contains("bf16") || s.contains("fp32") || s.contains("f16") { return .full }
        return .unknown
    }
}
