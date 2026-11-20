//
//  PathFinderTests.swift
//  InvasionesTests
//

import Foundation
import Testing
@testable import Invasiones

@MainActor
struct PathFinderTests {

    /// Builds a pathfinder on `grid` with a clock that never advances.
    private func makePathFinder(_ grid: TestGrid, clock: FakeClock = FakeClock()) -> PathFinder {
        let pathFinder = PathFinder(now: clock.now)
        pathFinder.load(grid: grid)
        return pathFinder
    }

    /// Checks that `path` goes from `start` to `target`, only through walkable tiles,
    /// one step (straight or diagonal) at a time.
    private func expectValidPath(_ path: [Point], from start: Point, to target: Point,
                                 on grid: TestGrid) {
        // The pathfinder returns the destination first and the origin last.
        #expect(path.first == target)
        #expect(path.last == start)
        for p in path {
            #expect(grid.isWalkable(x: p.i, y: p.j), "\(p) is not walkable")
        }
        for (a, b) in zip(path, path.dropFirst()) {
            #expect(max(abs(a.i - b.i), abs(a.j - b.j)) == 1, "\(a) → \(b) is not a single step")
        }
    }

    @Test func straightLineOnOpenGrid() throws {
        let grid = TestGrid([
            ".....",
        ])
        let path = try #require(makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 0, targetJ: 4)).points

        #expect(path == [Point(i: 0, j: 4), Point(i: 0, j: 3), Point(i: 0, j: 2),
                         Point(i: 0, j: 1), Point(i: 0, j: 0)])
    }

    @Test func prefersDiagonalOverTwoStraightSteps() throws {
        // Diagonal costs 14, two straight steps cost 20, so (0,0) → (2,2) is three points.
        let grid = TestGrid([
            "...",
            "...",
            "...",
        ])
        let path = try #require(makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 2, targetJ: 2)).points

        #expect(path == [Point(i: 2, j: 2), Point(i: 1, j: 1), Point(i: 0, j: 0)])
    }

    @Test func goesAroundAWall() throws {
        let grid = TestGrid([
            ".....",
            "###..",
            ".....",
        ])
        let start = Point(i: 0, j: 0), target = Point(i: 2, j: 0)
        let path = try #require(makePathFinder(grid)
            .findShortestPath(startI: start.i, startJ: start.j,
                              targetI: target.i, targetJ: target.j)).points

        expectValidPath(path, from: start, to: target, on: grid)
        #expect(path.contains(Point(i: 1, j: 3)), "path should pass through the gap at (1,3)")
    }

    @Test func doesNotCutCornersPastBlockedTiles() throws {
        // A diagonal step is only allowed when both adjacent straight tiles are walkable.
        let grid = TestGrid([
            ".#",
            "..",
        ])
        let path = try #require(makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 1, targetJ: 1)).points

        #expect(path == [Point(i: 1, j: 1), Point(i: 1, j: 0), Point(i: 0, j: 0)])
    }

    @Test func returnsNilWhenTargetIsEnclosed() {
        let grid = TestGrid([
            ".....",
            "..###",
            "..#.#",
            "..###",
        ])
        let path = makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 2, targetJ: 3)

        #expect(path == nil)
    }

    @Test func returnsNilWhenTargetIsNotWalkable() {
        let grid = TestGrid([
            "..#",
        ])
        let path = makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 0, targetJ: 2)

        #expect(path == nil)
    }

    @Test func returnsNilWhenTargetIsOutOfBounds() {
        let grid = TestGrid([
            "...",
        ])
        let path = makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 5, targetJ: 5)

        #expect(path == nil)
    }

    @Test func avoidsExtraBlockedTiles() throws {
        let grid = TestGrid([
            "...",
            "...",
            "...",
        ])
        let start = Point(i: 0, j: 0), target = Point(i: 2, j: 2)
        let path = try #require(makePathFinder(grid)
            .findShortestPath(startI: start.i, startJ: start.j,
                              targetI: target.i, targetJ: target.j,
                              blockedTiles: [(i: 1, j: 1)])).points

        expectValidPath(path, from: start, to: target, on: grid)
        #expect(!path.contains(Point(i: 1, j: 1)))
    }

    @Test func returnsNilWhenTargetIsInExtraBlockedTiles() {
        let grid = TestGrid([
            "...",
        ])
        let path = makePathFinder(grid)
            .findShortestPath(startI: 0, startJ: 0, targetI: 0, targetJ: 2,
                              blockedTiles: [(i: 0, j: 2)])

        #expect(path == nil)
    }

    @Test func seesTilesBlockedAfterLoading() throws {
        // In the game, Map.invalidateTile blocks tiles while a level is running.
        let grid = TestGrid([
            "...",
            "...",
        ])
        let pathFinder = makePathFinder(grid)
        grid.block(x: 0, y: 1)

        let path = try #require(pathFinder
            .findShortestPath(startI: 0, startJ: 0, targetI: 0, targetJ: 2)).points

        #expect(!path.contains(Point(i: 0, j: 1)))
        expectValidPath(path, from: Point(i: 0, j: 0), to: Point(i: 0, j: 2), on: grid)
    }

    @Test func timesOutOnSlowSearches() {
        // Each clock read moves time forward past the 4.5 s limit.
        let clock = FakeClock()
        clock.stepPerRead = 5
        let grid = TestGrid([
            ".....",
        ])
        let path = makePathFinder(grid, clock: clock)
            .findShortestPath(startI: 0, startJ: 0, targetI: 0, targetJ: 4)

        #expect(path == nil)
    }

    @Test func returnsNilWithoutAGrid() {
        let pathFinder = PathFinder()
        let path = pathFinder.findShortestPath(startI: 0, startJ: 0, targetI: 0, targetJ: 1)

        #expect(path == nil)
    }
}
