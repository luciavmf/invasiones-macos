//
//  BattlefieldTests.swift
//  InvasionesTests
//
//  Map objects and units on a hand-made battlefield, without loading an episode.
//

import Testing
@testable import Invasiones

@MainActor
struct MapObjectTests {

    private let grid = TestGrid(["....."])

    @Test func tileToWorldUsesTheBattlefieldTileSize() {
        let battlefield = Battlefield(map: grid, camera: Camera(x: 0, y: 0, height: 600))

        let object = MapObject(surface: nil, i: 4, j: 2, battlefield: battlefield)

        // x = ((i - j) * 64 / 2) >> 1, y = ((i + j) * 32 / 2) >> 1
        #expect(object.worldPos == (32, 48))
    }

    @Test func screenPositionFollowsTheCamera() {
        let battlefield = Battlefield(map: grid, camera: Camera(x: 100, y: 50, height: 600))
        let object = MapObject(surface: nil, i: 0, j: 0, battlefield: battlefield)

        object.setTilePosition(i: 4, j: 2)

        #expect(object.x == 32 + 100)
        #expect(object.y == 48 + 50)
    }

    @Test func unitsWithoutABattlefieldStayAtTheOrigin() {
        let unit = GameUnit()

        #expect(unit.tileToWorld(i: 4, j: 2) == (0, 0))
    }
}

@MainActor
struct UnitOnBattlefieldTests {

    // A corridor with the infirmary's tiles blocked at the far end.
    private let grid = TestGrid(["....##"])
    private let sound = FakeSound()

    private func makeUnit(at position: (x: Int, y: Int), camera: Camera? = nil) -> GameUnit {
        let pathFinder = PathFinder()
        pathFinder.load(grid: grid)
        let camera = camera ?? Camera(x: 0, y: 0, height: 600)
        let unit = GameUnit(battlefield: Battlefield(map: grid, camera: camera),
                            pathFinder: pathFinder, sound: sound)
        unit.setTilePosition(i: position.x, j: position.y)
        return unit
    }

    @Test func healWalksToTheLastFreeTileBeforeTheInfirmary() throws {
        let unit = makeUnit(at: (0, 0))

        unit.heal(x: 0, y: 5)

        #expect(unit.currentState == .moving)
        let path = try #require(unit.pathToFollow).points
        #expect(path == [Point(i: 0, j: 3), Point(i: 0, j: 2), Point(i: 0, j: 1)])
    }

    @Test func healWithNoFreeTileLeavesTheUnitIdle() {
        let unit = makeUnit(at: (0, 4))   // a blocked tile, so the walk finds nothing

        unit.heal(x: 0, y: 5)

        #expect(unit.currentState == .idle)
        #expect(unit.pathToFollow == nil)
    }

    @Test func isOnScreenFollowsTheCamera() {
        let visible = makeUnit(at: (0, 0))
        let scrolledAway = makeUnit(at: (0, 0), camera: Camera(x: -2000, y: 0, height: 600))

        #expect(visible.isOnScreen())
        #expect(!scrolledAway.isOnScreen())
    }
}
