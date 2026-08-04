//
//  JSONLLogTailTests.swift
//  MCPKitTests
//
//  Exercises the bounded tail reader independently from the JSONL store's other file
//  maintenance behavior.
//

import Foundation
@testable import MCPKit
import Testing

@Suite("JSONL log tail loading")
struct JSONLLogTailTests {
    @Test
    func `load reads only a bounded tail of a large file`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "log.jsonl")
        var oversizedPrefix = Data(repeating: UInt8(ascii: "x"), count: maximumJSONLLoadBytes * 2)
        oversizedPrefix.append(UInt8(ascii: "\n"))
        try oversizedPrefix.write(to: url)
        let log = JSONLLog<LogRow>(directory: directory, fileName: "log.jsonl", maxEntries: 2)
        for n in 1 ... 3 { log.append(LogRow(n: n, text: "\(n)")) }

        let tail = try #require(boundedTailData(from: url, maximumBytes: maximumJSONLLoadBytes))
        #expect(tail.count <= maximumJSONLLoadBytes)
        #expect(tail.first != UInt8(ascii: "x"))
        #expect(log.load().map(\.n) == [2, 3])
    }

    @Test
    func `bounded tail preserves a record at exact window boundaries`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "JSONLLogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "boundary.jsonl")
        try Data("old\nnew\n".utf8).write(to: url)

        // Four bytes starts exactly at "new"; five starts at its preceding newline.
        #expect(boundedTailData(from: url, maximumBytes: 4) == Data("new\n".utf8))
        #expect(boundedTailData(from: url, maximumBytes: 5) == Data("new\n".utf8))
    }
}
