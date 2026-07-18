//
//  JSONLLogTests.swift
//  MCPKitTests
//
//  Exercises the append-only JSONL store: round-trips, the read cap, trimming, and the
//  durability properties the type promises - atomic concurrent appends, tolerance of a
//  byte-damaged line, and leaving an existing log alone when it cannot be written.
//

import Foundation
import Testing

@testable import MCPKit

/// A small `Codable & Sendable` entry for exercising `JSONLLog` round-trips.
private struct LogRow: Codable, Sendable, Equatable {
    let n: Int
    let text: String
}

@Suite("JSONL log")
struct JSONLLogTests {
    /// A log in a fresh temp directory, plus that directory (so a test can inspect/tear it
    /// down). Each call gets a unique directory so tests don't collide.
    private func makeLog(maxEntries: Int) -> (log: JSONLLog<LogRow>, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let log = JSONLLog<LogRow>(directory: directory, fileName: "log.jsonl", maxEntries: maxEntries)
        return (log, directory)
    }

    @Test
    func `append then load round-trips entries oldest first`() {
        let (log, directory) = makeLog(maxEntries: 30)
        defer { try? FileManager.default.removeItem(at: directory) }

        let rows = [LogRow(n: 1, text: "a"), LogRow(n: 2, text: "b"), LogRow(n: 3, text: "c")]
        for row in rows { log.append(row) }

        #expect(log.load() == rows)
    }

    @Test
    func `load skips a malformed line`() throws {
        let (log, directory) = makeLog(maxEntries: 30)
        defer { try? FileManager.default.removeItem(at: directory) }

        log.append(LogRow(n: 1, text: "a"))
        // Inject a torn/garbage line between two valid ones, as a concurrent append might.
        let url = directory.appending(path: "log.jsonl")
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not json}\n".utf8))
        try handle.close()
        log.append(LogRow(n: 2, text: "b"))

        #expect(log.load() == [LogRow(n: 1, text: "a"), LogRow(n: 2, text: "b")])
    }

    @Test
    func `load caps at maxEntries keeping the newest`() {
        let (log, directory) = makeLog(maxEntries: 3)
        defer { try? FileManager.default.removeItem(at: directory) }

        for n in 1 ... 10 { log.append(LogRow(n: n, text: "\(n)")) }

        // The last three appended survive the read cap, oldest of those first.
        #expect(log.load().map(\.n) == [8, 9, 10])
    }

    @Test
    func `trim rewrites the file down to the cap`() throws {
        let (log, directory) = makeLog(maxEntries: 3)
        defer { try? FileManager.default.removeItem(at: directory) }

        for n in 1 ... 10 { log.append(LogRow(n: n, text: "\(n)")) }
        log.trim()

        // After trimming, the on-disk file itself holds only the last three lines.
        let url = directory.appending(path: "log.jsonl")
        let text = try String(contentsOf: url, encoding: .utf8)
        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: true).count
        #expect(lineCount == 3)
        #expect(log.load().map(\.n) == [8, 9, 10])
    }

    @Test
    func `concurrent appends from several writers all survive`() {
        let writers = 4
        let perWriter = 500
        let (log, directory) = makeLog(maxEntries: writers * perWriter)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Seek-then-write loses entries and tears lines here: two writers resolve the same
        // end-of-file offset and both write there. An O_APPEND descriptor cannot.
        DispatchQueue.concurrentPerform(iterations: writers) { writer in
            for n in 0 ..< perWriter {
                log.append(LogRow(n: writer * perWriter + n, text: "row"))
            }
        }

        let loaded = log.load()
        #expect(loaded.count == writers * perWriter)
        // Every line is intact and distinct, i.e. none was overwritten or torn.
        #expect(Set(loaded.map(\.n)).count == writers * perWriter)
    }

    @Test
    func `a line of invalid UTF-8 doesn't hide the rest of the log`() throws {
        let (log, directory) = makeLog(maxEntries: 30)
        defer { try? FileManager.default.removeItem(at: directory) }

        log.append(LogRow(n: 1, text: "a"))
        log.append(LogRow(n: 2, text: "b"))
        // A truncated multi-byte sequence, as a torn write elsewhere could leave behind.
        let url = directory.appending(path: "log.jsonl")
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0xE2, 0x82, 0x0A]))
        try handle.close()
        log.append(LogRow(n: 3, text: "c"))

        // Decoding the file as one String would fail on that byte pair and lose all three.
        #expect(log.load() == [LogRow(n: 1, text: "a"), LogRow(n: 2, text: "b"), LogRow(n: 3, text: "c")])
    }

    @Test
    func `trim still compacts a file holding invalid UTF-8`() throws {
        let (log, directory) = makeLog(maxEntries: 3)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "log.jsonl")
        for n in 1 ... 10 { log.append(LogRow(n: n, text: "\(n)")) }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0xE2, 0x82, 0x0A]))
        try handle.close()

        // Otherwise trim is a permanent no-op and the log grows without bound.
        log.trim()
        let lineCount = try Data(contentsOf: url)
            .split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).count
        #expect(lineCount == 3)
    }

    @Test
    func `append leaves an existing log untouched when the file can't be opened`() throws {
        // Permission checks don't apply to root, so this can only prove anything as a
        // normal user.
        try #require(getuid() != 0)
        let (log, directory) = makeLog(maxEntries: 30)
        let url = directory.appending(path: "log.jsonl")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let rows = [LogRow(n: 1, text: "a"), LogRow(n: 2, text: "b")]
        for row in rows { log.append(row) }
        // The file is unwritable but its directory isn't, so a write-a-temp-and-rename
        // fallback would succeed - and replace the whole log with this one line.
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        log.append(LogRow(n: 3, text: "after-readonly"))

        #expect(log.load() == rows)
    }

    @Test
    func `clear removes the file so load returns empty`() {
        let (log, directory) = makeLog(maxEntries: 30)
        defer { try? FileManager.default.removeItem(at: directory) }

        log.append(LogRow(n: 1, text: "a"))
        #expect(!log.load().isEmpty)
        log.clear()
        #expect(log.load().isEmpty)
    }
}
