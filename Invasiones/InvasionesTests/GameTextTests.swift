//
//  GameTextTests.swift
//  InvasionesTests
//
//  Parsing of the localised strings files.
//

import Foundation
import Testing
@testable import Invasiones

@MainActor
struct GameTextTests {

    private func parse(_ json: String) throws -> (strings: [StringID: String], tips: [String]) {
        try GameText.parse(Data(json.utf8), filename: "test.json")
    }

    @Test func stringsAreKeyedByStringID() throws {
        let parsed = try parse(#"{"window_caption": "Invasiones", "sound_label": "Sound"}"#)

        #expect(parsed.strings == [.windowCaption: "Invasiones", .soundLabel: "Sound"])
    }

    @Test func unknownKeysAreIgnored() throws {
        let parsed = try parse(#"{"not_a_string_id": "x", "you_won": "You Won!"}"#)

        #expect(parsed.strings == [.youWon: "You Won!"])
    }

    @Test func missingKeysAreLeftOut() throws {
        let parsed = try parse("{}")

        #expect(parsed.strings.isEmpty)
        #expect(parsed.tips.isEmpty)
    }

    @Test func tipsAreReadSeparately() throws {
        let parsed = try parse(#"{"tips": ["first", "second"]}"#)

        #expect(parsed.tips == ["first", "second"])
        #expect(!parsed.strings.values.contains("first"))
    }

    @Test func invalidJSONThrowsParsingFailed() {
        #expect {
            try parse("not json")
        } throws: { error in
            if case GameError.parsingFailed = error { return true }
            return false
        }
    }

    @Test(arguments: Language.allCases)
    func bundledFileHasEveryKey(language: Language) throws {
        let path = try #require(Utils.getPath(language.filename))
        let data = try Data(contentsOf: URL(fileURLWithPath: path))

        let parsed = try GameText.parse(data, filename: language.filename)

        let missing = StringID.allCases.filter { parsed.strings[$0] == nil }
        #expect(missing.isEmpty, "\(language.filename) is missing \(missing)")
        #expect(!parsed.tips.isEmpty)
    }
}
