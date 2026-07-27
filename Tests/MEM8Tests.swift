import Testing
import Foundation

@testable import HFMac

struct MEM8WaveTests {

    @Test("MEM8Wave encodes text as wave with non-zero frequency")
    func testWaveEncoding() {
        let wave = MEM8Wave(kind: "user", text: "write a fibonacci function in rust")
        #expect(wave.frequency > 0)
        #expect(wave.frequency <= 1000)
        #expect(wave.amplitude > 0)
        #expect(wave.amplitude <= 1.0)
        #expect(wave.kind == "user")
        #expect(!wave.text.isEmpty)
    }

    @Test("Code text maps to beta band (300-500 Hz)")
    func testCodeBand() {
        let wave = MEM8Wave(kind: "user", text: "func main() { println! }")
        #expect(wave.frequency >= 300, "Code should map to beta band (300-500 Hz)")
        #expect(wave.frequency <= 500)
    }

    @Test("Math text maps to gamma band (500-800 Hz)")
    func testMathBand() {
        let wave = MEM8Wave(kind: "user", text: "solve for x: 2x + 5 = 13")
        #expect(wave.frequency >= 500, "Math should map to gamma band (500-800 Hz)")
        #expect(wave.frequency <= 800)
    }

    @Test("Self-interference is constructive (> noise floor)")
    func testSelfInterference() {
        let text = "hello world"
        let w1 = MEM8Wave(kind: "user", text: text, date: Date())
        let w2 = MEM8Wave(kind: "user", text: text, date: Date())
        let interference = w1.interference(with: w2)
        // Same text → same frequency + same phase → constructive
        // amplitude = 0.3 + 0.7 * sqrt(11/2000) ≈ 0.35, squared ≈ 0.12
        #expect(interference > 0.05, "Self-interference should be above noise floor")
        #expect(interference > 0, "Self-interference should be positive")
    }

    @Test("Dissimilar texts interfere weakly")
    func testDissimilarInterference() {
        let w1 = MEM8Wave(kind: "user", text: "write rust fibonacci function")
        let w2 = MEM8Wave(kind: "user", text: "what is the weather today")
        let interference = w1.interference(with: w2)
        // Dissimilar content → different bands → weak interference
        #expect(interference < w1.interference(with: w1), "Dissimilar texts should interfere less than identical")
    }

    @Test("EntheaiMemory records and recalls via wave interference")
    func testMemoryRecall() {
        var mem = EntheaiMemory()
        mem.record(kind: "user", text: "how do I write a rust function")
        mem.record(kind: "assistant", text: "use fn keyword to define a function in rust")
        mem.record(kind: "user", text: "what is the capital of france")

        let hits = mem.recall("rust function")
        #expect(!hits.isEmpty, "Should recall rust-related spans")
        #expect(hits.contains(where: { $0.text.contains("rust") }), "Recalled spans should contain rust")
    }

    @Test("EntheaiMemory returns nil context message on empty recall")
    func testEmptyRecall() {
        let mem = EntheaiMemory()
        let ctx = mem.contextMessage(for: "something completely unrelated")
        #expect(ctx == nil, "Empty memory should return nil context")
    }

    @Test("Wave value calculation produces deterministic output")
    func testWaveValue() {
        let wave = MEM8Wave(kind: "user", text: "test", date: Date(timeIntervalSince1970: 0))
        let v1 = wave.value(at: 0.0)
        let v2 = wave.value(at: 0.5)
        #expect(v1 != v2, "Wave should produce different values at different time points")
        #expect(abs(v1) <= wave.amplitude, "Wave value should be bounded by amplitude")
    }

    @Test("MEM8Band classification covers all domains")
    func testAllDomains() {
        #expect(MEM8Band.band(for: "def hello():") == .beta)
        #expect(MEM8Band.band(for: "solve the equation for x") == .gamma)
        #expect(MEM8Band.band(for: "summarize the key points") == .theta)
        #expect(MEM8Band.band(for: "write a poem about stars") == .hyperGamma)
        #expect(MEM8Band.band(for: "how are you today") == .alpha)
    }
}
