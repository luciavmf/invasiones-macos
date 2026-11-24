//
//  LineOfSightTests.swift
//  InvasionesTests
//
//  getLineOfSightPosition on hand-made grids.
//

import Testing
@testable import Invasiones

@MainActor
struct LineOfSightTests {

    @Test func returnsTheStartWhenItIsWalkable() throws {
        let grid = TestGrid(["....."])

        let p = try #require(grid.getLineOfSightPosition(x1: 0, x2: 0, y1: 0, y2: 4))

        #expect(Point(i: p.x, j: p.y) == Point(i: 0, j: 0))
    }

    @Test func skipsBlockedTilesTowardTheTarget() throws {
        let grid = TestGrid(["##..."])

        let p = try #require(grid.getLineOfSightPosition(x1: 0, x2: 0, y1: 0, y2: 4))

        #expect(Point(i: p.x, j: p.y) == Point(i: 0, j: 2))
    }

    @Test func followsDiagonals() throws {
        let grid = TestGrid([
            "#...",
            ".#..",
            "....",
            "....",
        ])

        let p = try #require(grid.getLineOfSightPosition(x1: 0, x2: 3, y1: 0, y2: 3))

        #expect(Point(i: p.x, j: p.y) == Point(i: 2, j: 2))
    }

    @Test func neverChecksTheTargetItself() {
        // As in the original: the walk stops before reaching (x2, y2).
        let grid = TestGrid(["####."])

        #expect(grid.getLineOfSightPosition(x1: 0, x2: 0, y1: 0, y2: 4) == nil)
    }
}
