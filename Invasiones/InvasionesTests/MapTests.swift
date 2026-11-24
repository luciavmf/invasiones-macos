//
//  MapTests.swift
//  InvasionesTests
//
//  Queries on the first level's map (nivel1a.tmx).
//

import Testing
@testable import Invasiones

@MainActor
struct MapTests {

    private let map: Map

    init() throws {
        try ResourceManager.shared.loadResourcePaths()
        map = Map(camera: Camera(x: 0, y: 0, height: 600))
        try map.load(level: 0)
    }

    @Test func infirmaryTilesAreFoundInTheBuildingsLayer() {
        // The infirmary covers map tiles 95...99 × 8...9.
        #expect(map.isInfirmary(x: 95, y: 8))
        #expect(map.isInfirmary(x: 99, y: 9))
    }

    @Test func otherTilesAreNotAnInfirmary() {
        #expect(!map.isInfirmary(x: 0, y: 0))     // no building
        #expect(!map.isInfirmary(x: 97, y: 0))    // a house in the same tileset
        #expect(!map.isInfirmary(x: -1, y: 8))    // off the map
        #expect(!map.isInfirmary(x: 95, y: map.height))
    }
}
