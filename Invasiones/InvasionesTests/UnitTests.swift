//
//  UnitTests.swift
//  InvasionesTests
//
//  Unit behavior with injected fakes (pathfinder on a hand-made grid, recorded sound).
//

import Foundation
import Testing
@testable import Invasiones

@MainActor
struct UnitTests {

    private let grid = TestGrid([
        ".....",
        "###..",
        ".....",
    ])
    private let sound = FakeSound()

    private func makeUnit(at position: (x: Int, y: Int)) -> GameUnit {
        let pathFinder = PathFinder()
        pathFinder.load(grid: grid)
        let unit = GameUnit(pathFinder: pathFinder, sound: sound)
        unit.physicalTilePos = position
        return unit
    }

    @Test func moveFollowsThePathFromTheInjectedPathFinder() throws {
        let unit = makeUnit(at: (0, 0))

        unit.move(x: 0, y: 3)

        #expect(unit.currentState == .moving)
        // The origin is dropped; the next step is popped from the end.
        let path = try #require(unit.pathToFollow).points
        #expect(path == [Point(i: 0, j: 3), Point(i: 0, j: 2), Point(i: 0, j: 1)])
    }

    @Test func moveToAnUnreachableTileLeavesTheUnitIdle() {
        let unit = makeUnit(at: (0, 0))

        unit.move(x: 1, y: 0)   // a wall tile

        #expect(unit.currentState == .idle)
        #expect(unit.pathToFollow == nil)
    }

    @Test func dyingPlaysTheDeathSound() {
        let unit = makeUnit(at: (0, 0))   // default type is UNIDAD_PATRICIO

        unit.morir()

        #expect(unit.currentState == .dying)
        #expect(unit.isDead())
        #expect(sound.played == [Res.SFX_MUERTE_PATRICIO])
    }

    @Test func dragRectangleAroundTheUnitSelectsIt() {
        let unit = makeUnit(at: (0, 0))
        unit.x = 500
        unit.y = 400

        let selected = unit.selectIfInRect(x: 0, y: 0, w: 1000, h: 700)

        #expect(selected)
        #expect(unit.isSelected)
    }

    @Test func dragRectangleElsewhereLeavesTheUnitUnselected() {
        let unit = makeUnit(at: (0, 0))
        unit.x = 500
        unit.y = 400

        let selected = unit.selectIfInRect(x: 700, y: 0, w: 200, h: 200)

        #expect(!selected)
        #expect(!unit.isSelected)
    }
}
