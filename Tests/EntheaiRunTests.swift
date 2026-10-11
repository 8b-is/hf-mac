import Testing
import Foundation

@testable import HFMac

/// Regression tests for the v0.12.0 background crash: `EntheaiClient.run`
/// could resume its checked continuation twice when the timeout fired and
/// `terminate()` unblocked `waitUntilExit()` — Swift then traps with
/// "continuation resumed more than once" (EXC_BREAKPOINT, Services.swift
/// `closure #1 in EntheaiClient.run`).
struct EntheaiRunTests {

    @Test("A nonzero process exit fails even when it prints plausible output")
    func nonzeroExitIsFailure() async throws {
        for (status, body) in [(7, "echo partial-result\necho synthetic-error >&2\n"),
                               (9, ""), (11, "echo stdout-diagnostic\n")] {
            let script = FileManager.default.temporaryDirectory
                .appendingPathComponent("hfmac-failing-\(UUID().uuidString).sh")
            try "#!/bin/sh\n\(body)exit \(status)\n".write(
                to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                  ofItemAtPath: script.path)
            defer { try? FileManager.default.removeItem(at: script) }
            var client = EntheaiClient()
            client.binaryPath = script.path
            client.timeoutSecs = 5
            do {
                _ = try await client.run(prompt: "synthetic fixture")
                Issue.record("Exit \(status) incorrectly returned success")
            } catch let error as EntheaiError {
                guard case .processFailed(let observedStatus, let diagnostic) = error else {
                    Issue.record("Expected a process failure, got \(error)")
                    continue
                }
                #expect(observedStatus == status)
                #expect(error.localizedDescription.contains("\(status)"))
                if status == 7 {
                    #expect(diagnostic == "synthetic-error")
                } else if status == 11 {
                    #expect(diagnostic == "stdout-diagnostic")
                } else {
                    #expect(diagnostic.isEmpty)
                }
            }
        }
    }

    @Test("A signal-terminated process fails instead of returning partial output")
    func signalTerminationIsFailure() async throws {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("hfmac-signaled-\(UUID().uuidString).sh")
        try "#!/bin/sh\necho partial-result\nkill -TERM $$\n".write(
            to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: script.path)
        defer { try? FileManager.default.removeItem(at: script) }
        var client = EntheaiClient()
        client.binaryPath = script.path
        client.timeoutSecs = 5
        do {
            _ = try await client.run(prompt: "synthetic fixture")
            Issue.record("Signal termination incorrectly returned success")
        } catch let error as EntheaiError {
            guard case .terminated(let signal, let diagnostic) = error else {
                Issue.record("Expected signal termination, got \(error)")
                return
            }
            #expect(signal == SIGTERM)
            #expect(diagnostic == "partial-result")
        }
    }

    @Test("Successful processes may write a diagnostic to stderr")
    func zeroExitWithDiagnosticSucceeds() async throws {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("hfmac-diagnostic-\(UUID().uuidString).sh")
        try "#!/bin/sh\necho completed-result\necho synthetic-warning >&2\nexit 0\n".write(
            to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: script.path)
        defer { try? FileManager.default.removeItem(at: script) }
        var client = EntheaiClient()
        client.binaryPath = script.path
        client.timeoutSecs = 5
        let result = try await client.run(prompt: "synthetic fixture")
        #expect(result.output.contains("completed-result"))
        #expect(result.output.contains("synthetic-warning"))
    }

    @Test("ContinuationGate lets exactly the first resume through")
    func gateResumesOnce() {
        let gate = EntheaiClient.ContinuationGate()
        var count = 0
        gate.resumeOnce { count += 1 }
        gate.resumeOnce { count += 1 }
        gate.resumeOnce { count += 1 }
        #expect(count == 1)
    }

    @Test("A timeout produces one .timeout error — no double-resume trap")
    func timeoutResumesExactlyOnce() async throws {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("hfmac-slow-\(UUID().uuidString).sh")
        try "#!/bin/sh\nexec sleep 30\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: script.path)
        defer { try? FileManager.default.removeItem(at: script) }

        var client = EntheaiClient()
        client.binaryPath = script.path
        client.timeoutSecs = 1

        do {
            _ = try await client.run(prompt: "ignored by the script")
            Issue.record("expected a timeout, got a result")
        } catch let error as EntheaiError {
            guard case .timeout = error else {
                Issue.record("expected .timeout, got \(error)")
                return
            }
        }
    }

    @Test("A fast, well-behaved process still returns its output")
    func happyPathStillResolves() async throws {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("hfmac-fast-\(UUID().uuidString).sh")
        try "#!/bin/sh\necho hello-from-the-test\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: script.path)
        defer { try? FileManager.default.removeItem(at: script) }

        var client = EntheaiClient()
        client.binaryPath = script.path
        client.timeoutSecs = 10

        let result = try await client.run(prompt: "ignored")
        #expect(result.output.contains("hello-from-the-test"))
    }
}
