//
//  JSONLLog.swift
//  MCPKit
//
//  A tiny append-only JSONL store for an in-app MCP server's activity log. The headless
//  `--mcp` process is a separate launch from a running GUI, so it records what it does to
//  a small file in a shared container both can reach; a settings pane can tail that file.
//
//  It provides an `O_APPEND` append (creating the file on the first write), a tolerant
//  line-by-line parse that skips a torn or malformed line rather than failing the whole
//  read, a `maxEntries` cap, and a `clear()` that removes the file. The entry schema and
//  the cap are the generic parameters; each app keeps its own `Entry` type.
//
//  Concurrency: several MCP clients can each launch their own `--mcp` process, so writes
//  are append-only and go through an `O_APPEND` descriptor, where the kernel makes the
//  position-and-write a single step - the property the multi-process design rests on.
//  Reads split the file's bytes and decode each line separately, so a line damaged by
//  anything else on the system doesn't take the rest of the log with it. Trimming to the
//  last N entries is done by the single GUI reader when it loads, avoiding multi-process
//  rewrite races. Every member is nonisolated, so the headless server can append from any
//  context.
//

import Foundation

/// An append-only JSONL log of `Entry` values, shared by a GUI reader and one or more
/// headless writer processes via a file in a directory both can reach.
///
/// The store owns only its file location and cap; the caller decides where entries come
/// from and how they're shown. `Entry` is `Codable & Sendable` so the log crosses process
/// and isolation boundaries safely.
public struct JSONLLog<Entry: Codable & Sendable>: Sendable {
    /// The directory holding the log file. Created on demand when appending.
    public let directory: URL

    /// The log file's name within `directory`, e.g. `"mcp-activity.jsonl"`.
    public let fileName: String

    /// The most recent entries kept; older ones are dropped when the GUI calls `trim()`,
    /// and reads return at most this many.
    public let maxEntries: Int

    private let encode: @Sendable (Entry) -> Data?
    private let decode: @Sendable (Data) -> Entry?

    /// Creates a log at `directory/fileName`, keeping at most `maxEntries`.
    ///
    /// Dates are encoded and decoded as ISO-8601 by default; pass custom
    /// `encoder`/`decoder` to change that.
    public init(
        directory: URL,
        fileName: String,
        maxEntries: Int,
        encoder: JSONEncoder = JSONLLog.iso8601Encoder,
        decoder: JSONDecoder = JSONLLog.iso8601Decoder
    ) {
        self.directory = directory
        self.fileName = fileName
        self.maxEntries = maxEntries
        // Capture the coders behind Sendable closures so the struct stays Sendable
        // (JSONEncoder/JSONDecoder are reference types).
        encode = { try? encoder.encode($0) }
        decode = { try? decoder.decode(Entry.self, from: $0) }
    }

    /// A JSON encoder writing dates as ISO-8601 - the default for a `JSONLLog`.
    public static var iso8601Encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// A JSON decoder reading ISO-8601 dates - the default for a `JSONLLog`.
    public static var iso8601Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// The full path to the log file, creating `directory` if needed. Returns nil only
    /// when the directory can't be created.
    private var fileURL: URL? {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }

        return directory.appending(path: fileName)
    }

    /// Appends `entry` as one JSON line, creating the file if it doesn't exist yet.
    ///
    /// The file is opened `O_WRONLY|O_APPEND|O_CREAT`, so the kernel positions each write
    /// at the current end of file as part of the write itself. That is what makes the
    /// multi-process appending this type is designed for safe: two `--mcp` processes
    /// writing at once can't resolve the same offset and overwrite one another. A
    /// seek-then-write handle would lose entries and tear lines under exactly that load.
    ///
    /// A non-encodable entry, an unopenable file, and a failed write are all silently
    /// dropped: a log line is never worth failing a tool call over, and - crucially - a
    /// log the process can't write to is left exactly as it is rather than replaced.
    public func append(_ entry: Entry) {
        guard let url = fileURL,
              let data = encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }

        let payload = Data((line + "\n").utf8)
        let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }

            return open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        }
        guard descriptor >= 0 else { return }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        defer { try? handle.close() }
        try? handle.write(contentsOf: payload)
    }

    /// The stored entries, oldest first, capped to the last `maxEntries`. Decodes
    /// tolerantly: a malformed line - torn JSON, or bytes that aren't even valid UTF-8 -
    /// is skipped rather than failing the whole read. An absent file reads as empty.
    public func load() -> [Entry] {
        let entries = rawLines().compactMap { decode(Data($0)) }
        return Array(entries.suffix(maxEntries))
    }

    /// The file's newline-separated lines as raw bytes, empty when it can't be read.
    ///
    /// Splitting the bytes rather than a decoded `String` is deliberate: decoding the file
    /// as one UTF-8 `String` fails outright on a single bad byte, so one torn append would
    /// make every entry in the log invisible. Each line is decoded on its own instead, and
    /// only the damaged one is lost.
    private func rawLines() -> [Data.SubSequence] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }

        return data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
    }

    /// Rewrites the file to only its last `maxEntries` lines when it has grown past the
    /// cap, so the log can't grow without bound. Call from the single GUI reader after a
    /// load, so it doesn't race the headless appenders. A no-op when already within the cap.
    public func trim() {
        guard let url = fileURL else { return }

        let lines = rawLines()
        guard lines.count > maxEntries else { return }

        var trimmed = Data()
        for line in lines.suffix(maxEntries) {
            trimmed.append(contentsOf: line)
            trimmed.append(UInt8(ascii: "\n"))
        }
        try? trimmed.write(to: url, options: .atomic)
    }

    /// Deletes the log file, e.g. so it doesn't outlive the data it describes.
    public func clear() {
        guard let url = fileURL else { return }

        try? FileManager.default.removeItem(at: url)
    }
}
