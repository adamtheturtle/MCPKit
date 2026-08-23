//
//  main.swift
//  JSONLLogAppendFixture
//
//  Appends N JSONL rows to a directory/file given on the command line so tests can
//  stress multi-process writers.
//

import Foundation
import MCPKit

struct Row: Codable, Sendable {
    let writer: Int
    let n: Int
}

guard CommandLine.arguments.count == 5,
      let writer = Int(CommandLine.arguments[3]),
      let count = Int(CommandLine.arguments[4])
else {
    fputs("usage: JSONLLogAppendFixture <directory> <fileName> <writer> <count>\n", stderr)
    exit(EXIT_FAILURE)
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileName = CommandLine.arguments[2]
let log = JSONLLog<Row>(directory: directory, fileName: fileName, maxEntries: count * 16)
for n in 0 ..< count {
    log.append(Row(writer: writer, n: n))
}
