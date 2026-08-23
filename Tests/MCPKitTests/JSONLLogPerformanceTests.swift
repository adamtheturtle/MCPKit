//
//  JSONLLogPerformanceTests.swift
//  MCPKitTests
//
//  Stresses JSONLLog.append under concurrent writers, including separate processes.
//

import Foundation
@testable import MCPKit
import Testing

private struct ProcessRow: Codable, Sendable, Equatable {
    let writer: Int
    let n: Int
}

@Suite("JSONL log performance")
struct JSONLLogPerformanceTests {
    @Test
    func `concurrent in-process appends remain complete under load`() {
        let writers = 8
        let perWriter = 1_000
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogPerf-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = JSONLLog<LogRow>(
            directory: directory,
            fileName: "perf.jsonl",
            maxEntries: writers * perWriter
        )

        let started = ContinuousClock.now
        DispatchQueue.concurrentPerform(iterations: writers) { writer in
            for n in 0 ..< perWriter {
                log.append(LogRow(n: writer * perWriter + n, text: "row"))
            }
        }
        let elapsed = ContinuousClock.now - started

        let loaded = log.load()
        #expect(loaded.count == writers * perWriter)
        #expect(Set(loaded.map(\.n)).count == writers * perWriter)
        #expect(elapsed < .seconds(30))
    }

    @Test
    func `concurrent processes appending all survive`() throws {
        let writers = 4
        let perWriter = 200
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogPerfProc-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fixture = Bundle(for: PerfBundleMarker.self).bundleURL
            .deletingLastPathComponent()
            .appending(path: "JSONLLogAppendFixture")
        #expect(FileManager.default.isExecutableFile(atPath: fixture.path))

        let processes: [Process] = try (0 ..< writers).map { writer in
            let process = Process()
            process.executableURL = fixture
            process.arguments = [directory.path, "perf.jsonl", "\(writer)", "\(perWriter)"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            return process
        }
        for process in processes {
            process.waitUntilExit()
            #expect(process.terminationStatus == EXIT_SUCCESS)
        }

        let log = JSONLLog<ProcessRow>(
            directory: directory,
            fileName: "perf.jsonl",
            maxEntries: writers * perWriter
        )
        let loaded = log.load()
        #expect(loaded.count == writers * perWriter)
        #expect(Set(loaded.map { "\($0.writer)-\($0.n)" }).count == writers * perWriter)
    }
}

private final class PerfBundleMarker: NSObject {}
