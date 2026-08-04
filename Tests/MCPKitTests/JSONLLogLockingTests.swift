//
//  JSONLLogLockingTests.swift
//  MCPKitTests
//
//  Deterministic coverage for coordination between pathname-replacing maintenance and
//  an appender which already has the active log inode open.
//

import Foundation
@testable import MCPKit
import Testing

@Suite("JSONL log locking")
struct JSONLLogLockingTests {
    @Test
    func `trim waits for an append that already opened the log`() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let seedLog = JSONLLog<LogRow>(directory: directory, fileName: "log.jsonl", maxEntries: 10)
        seedLog.append(LogRow(n: -1, text: "oldest"))
        seedLog.append(LogRow(n: 0, text: "old"))

        let appendOpened = DispatchSemaphore(value: 0)
        let allowAppend = DispatchSemaphore(value: 0)
        let appendFinished = DispatchSemaphore(value: 0)
        let trimFinished = DispatchSemaphore(value: 0)
        let log = JSONLLog<LogRow>(
            directory: directory,
            fileName: "log.jsonl",
            maxEntries: 1,
            beforeAppendWrite: {
                appendOpened.signal()
                allowAppend.wait()
            }
        )

        DispatchQueue.global().async {
            log.append(LogRow(n: 1, text: "new"))
            appendFinished.signal()
        }
        #expect(appendOpened.wait(timeout: .now() + 2) == .success)
        DispatchQueue.global().async {
            log.trim()
            trimFinished.signal()
        }

        #expect(trimFinished.wait(timeout: .now() + 0.2) == .timedOut)
        allowAppend.signal()
        #expect(appendFinished.wait(timeout: .now() + 2) == .success)
        #expect(trimFinished.wait(timeout: .now() + 2) == .success)
        #expect(log.load() == [LogRow(n: 1, text: "new")])
    }

    @Test
    func `append waits for clear and remains visible after clear returns`() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clearStarted = DispatchSemaphore(value: 0)
        let allowClear = DispatchSemaphore(value: 0)
        let clearFinished = DispatchSemaphore(value: 0)
        let appendFinished = DispatchSemaphore(value: 0)
        let log = JSONLLog<LogRow>(
            directory: directory,
            fileName: "log.jsonl",
            maxEntries: 10,
            beforeAppendWrite: nil,
            beforeClearRemove: {
                clearStarted.signal()
                allowClear.wait()
            }
        )
        log.append(LogRow(n: 0, text: "before-clear"))

        DispatchQueue.global().async {
            log.clear()
            clearFinished.signal()
        }
        #expect(clearStarted.wait(timeout: .now() + 2) == .success)
        DispatchQueue.global().async {
            log.append(LogRow(n: 1, text: "after-clear"))
            appendFinished.signal()
        }

        #expect(appendFinished.wait(timeout: .now() + 0.2) == .timedOut)
        allowClear.signal()
        #expect(clearFinished.wait(timeout: .now() + 2) == .success)
        #expect(appendFinished.wait(timeout: .now() + 2) == .success)
        #expect(log.load() == [LogRow(n: 1, text: "after-clear")])
    }
}
