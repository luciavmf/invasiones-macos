//
//  ResourceIDTests.swift
//  InvasionesTests
//
//  The resource ID enums use positions in data/res.json as raw values.
//  These tests fail if the file and the enums drift apart.
//

import Foundation
import Testing
@testable import Invasiones

@MainActor
struct ResourceIDTests {

    private let resources = ResourceManager()

    init() throws {
        try resources.loadResourcePaths()
    }

    /// The file name at the given position of a path list from res.json.
    private func fileName(_ paths: [String?], _ index: Int) -> String? {
        (paths[safe: index] ?? nil).map { ($0 as NSString).lastPathComponent }
    }

    @Test func soundIDsMatchResJSON() {
        let paths = resources.soundPaths
        #expect(paths.count == SoundID.allCases.count)
        #expect(fileName(paths, SoundID.splash.rawValue) == "otheme.ogg")
        #expect(fileName(paths, SoundID.patricioDeath.rawValue) == "patricio_muerto.wav")
        #expect(fileName(paths, SoundID.battle.rawValue) == "TOS-rbattle.ogg")
    }

    @Test func imageIDsMatchResJSON() {
        let paths = resources.imagePaths
        #expect(paths.count == ImageID.allCases.count)
        #expect(fileName(paths, ImageID.swordCursor.rawValue) == "cursor_espada.png")
        #expect(fileName(paths, ImageID.logo.rawValue) == "logo.png")
        #expect(fileName(paths, ImageID.background.rawValue) == "fondo.png")
        #expect(fileName(paths, ImageID.hud.rawValue) == "hud.png")
    }

    @Test func fontFamiliesMatchResJSON() {
        let paths = resources.fontPaths
        #expect(paths.count == FontFamily.allCases.count)
        #expect(fileName(paths, FontFamily.sans.rawValue) == "FreeSans.ttf")
        #expect(fileName(paths, FontFamily.lblack.rawValue) == "LBLACK.TTF")
    }

    @Test func unitTypesMatchResJSON() {
        let paths = resources.unitPaths
        #expect(paths.count == UnitType.allCases.count)
        #expect(fileName(paths, UnitType.patricio.rawValue) == "patricio.csv")
        #expect(fileName(paths, UnitType.british.rawValue) == "ingles.csv")
    }

    @Test func tilesetIDsMatchResJSON() {
        // scenarioPaths lists every tileset first, then the level maps.
        let paths = resources.scenarioPaths
        #expect(fileName(paths, TilesetID.debug.rawValue) == "debug.tsx")
        #expect(fileName(paths, TilesetID.grass.rawValue) == "pasto.tsx")
        #expect(fileName(paths, TilesetID.units.rawValue) == "unidades.tsx")
        #expect(fileName(paths, TilesetID.invalidated.rawValue) == "invalidados.tsx")
        #expect(fileName(paths, TilesetID.fort.rawValue) == "fuerte.tsx")
        #expect(fileName(paths, TilesetID.allCases.count) == "nivel1a.tmx")
    }

    @Test func tilesetNamesMapToIDs() {
        #expect(TilesetID(tsxName: "Pasto") == .grass)
        #expect(TilesetID(tsxName: "Unidades") == .units)
        #expect(TilesetID(tsxName: "Invalidados") == .invalidated)
        // Not mapped in the original, so they fall back to debug.
        #expect(TilesetID(tsxName: "Objetivos") == .debug)
        #expect(TilesetID(tsxName: "Debug") == .debug)
    }

    @Test func helpPagesAndScreensLineUp() {
        #expect(StringID.helpPages.count == AnimationID.helpScreens.count)
    }
}
