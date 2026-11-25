//
//  GameText.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Texto.cs — loads and caches localised strings from strings.json.
//

import Foundation

/// Loads and caches all localised strings from strings.json.
/// Strings are looked up by `StringID`, whose raw value is the JSON key.
/// Tips are stored separately in `GameText.tips`.
enum GameText {

    // MARK: - Static storage
    private static var s_strings: [StringID: String]?
    private static var s_tips: [String] = []

    // MARK: - Load
    static func loadStrings() throws {
        let filename = Language.current.filename
        guard let path = Utils.getPath(filename) else {
            throw GameError.fileNotFound("File \(filename) not found.")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let parsed = try parse(data, filename: filename)
        s_strings = parsed.strings
        s_tips = parsed.tips
    }

    /// Parses a strings JSON file without touching the cache.
    /// - Returns: The strings found for each `StringID` (missing keys are left out) and the tips.
    static func parse(_ data: Data, filename: String) throws -> (strings: [StringID: String], tips: [String]) {
        let raw: [String: Any]
        do {
            raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            throw GameError.parsingFailed("GameText: failed to parse \(filename): \(error).")
        }
        var strings: [StringID: String] = [:]
        for id in StringID.allCases {
            if let text = raw[id.rawValue] as? String {
                strings[id] = text
            }
        }
        return (strings, raw["tips"] as? [String] ?? [])
    }

    // MARK: - Access

    /// The text for the given string in the current language, or `""` if it is missing.
    static func text(_ id: StringID) -> String {
        if s_strings == nil { try? loadStrings() }
        return s_strings?[id] ?? ""
    }

    /// All gameplay tips for the current language. Pick with randomElement().
    static var tips: [String] {
        if s_strings == nil { try? loadStrings() }
        return s_tips
    }
}
