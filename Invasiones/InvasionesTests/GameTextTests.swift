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

    private func parse(_ json: String) throws -> (strings: [String], tips: [String]) {
        try GameText.parse(Data(json.utf8), filename: "test.json")
    }

    @Test func stringsAreIndexedByResConstants() throws {
        let parsed = try parse(#"{"window_caption": "Invasiones", "sound_label": "Sound"}"#)

        #expect(parsed.strings.count == GameText.keyCount)
        #expect(parsed.strings[Res.STR_WINDOW_CAPTION] == "Invasiones")
        #expect(parsed.strings[Res.STR_SOUND_LABEL] == "Sound")
    }

    @Test func missingKeysBecomeEmptyStrings() throws {
        let parsed = try parse("{}")

        #expect(parsed.strings.count == GameText.keyCount)
        #expect(parsed.strings.allSatisfy { $0.isEmpty })
        #expect(parsed.tips.isEmpty)
    }

    @Test func tipsAreReadSeparately() throws {
        let parsed = try parse(#"{"tips": ["first", "second"]}"#)

        #expect(parsed.tips == ["first", "second"])
        #expect(!parsed.strings.contains("first"))
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

        #expect(!parsed.strings.contains(""), "\(language.filename) is missing keys")
        #expect(!parsed.tips.isEmpty)
    }
}
