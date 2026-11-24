//
//  TestSupport.swift
//  InvasionesTests
//
//  Fakes and fixtures shared by the unit tests.
//

import CoreGraphics
import Foundation
@testable import Invasiones

/// A walkability grid built from strings: `.` is walkable, anything else is blocked.
/// Row index is `x` (the pathfinder's `i`), column index is `y` (`j`).
///
/// `PathFinder` holds its grid weakly, so keep a reference to the grid for as long as the test uses it.
///
/// It is also a `BattleMap`, with 64×32 tiles like the game's map, so units and map objects can be placed on it.
final class TestGrid: BattleMap {
    private var cells: [[Bool]]
    let tileWidth = 64
    let tileHeight = 32

    init(_ rows: [String]) {
        cells = rows.map { row in row.map { $0 == "." } }
    }

    func isWalkable(x: Int, y: Int) -> Bool {
        guard x >= 0, x < cells.count, y >= 0, y < cells[x].count else { return false }
        return cells[x][y]
    }

    /// Blocks a tile after the grid has been loaded, like `Map.invalidateTile` does in the game.
    func block(x: Int, y: Int) {
        cells[x][y] = false
    }
}

/// Records every call instead of playing audio.
final class FakeSound: SoundPlayer {
    private(set) var played: [SoundID] = []
    private(set) var stopped: [SoundID] = []

    @discardableResult
    func play(id: SoundID, loop: Int) -> Bool {
        played.append(id)
        return true
    }

    func stop(_ id: SoundID) {
        stopped.append(id)
    }
}

/// A mouse the test sets by hand.
final class FakePointer: PointerDevice {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var pressedButtons: [Int] = []
    var dragRect: CGRect = .zero
    var dragging = false
    var finishedDragging = false
    var cursor: Surface?

    func isDragging() -> Bool { dragging }
    func didFinishDragging() -> Bool { finishedDragging }
    func releaseButton(_ button: Int) { pressedButtons.removeAll { $0 == button } }

    func press(_ button: Int) { pressedButtons.append(button) }
}

/// The one tile under the pointer, as player input sees it.
final class FakeInputMap: InputMap {
    /// The map tile and the physical tile under the pointer.
    var tile = (x: 1, y: 2)
    var physicalTile = (x: 3, y: 4)
    /// Whether the physical tile under the pointer is walkable.
    var walkable = true
    /// Whether the map tile under the pointer is part of an infirmary.
    var infirmary = false

    func tiles(atScreenX x: Int, y: Int) -> (tile: (x: Int, y: Int), physicalTile: (x: Int, y: Int)) {
        (tile, physicalTile)
    }

    func isWalkable(x: Int, y: Int) -> Bool {
        walkable && (x, y) == physicalTile
    }

    func isInfirmary(x: Int, y: Int) -> Bool {
        infirmary && (x, y) == tile
    }
}

/// A clock the test advances by hand.
final class FakeClock {
    var current = Date(timeIntervalSinceReferenceDate: 0)
    /// Added to `current` every time the clock is read.
    var stepPerRead: TimeInterval = 0

    func now() -> Date {
        defer { current += stepPerRead }
        return current
    }
}

/// The game's `Unit`. Foundation also declares a `Unit` (measurement units), so the bare name is ambiguous here.
typealias GameUnit = Invasiones.Unit

/// Path points as comparable values (tuples are not `Equatable` in arrays).
struct Point: Hashable, CustomStringConvertible {
    let i: Int
    let j: Int
    var description: String { "(\(i),\(j))" }
}

extension Array where Element == (i: Int, j: Int) {
    var points: [Point] { map { Point(i: $0.i, j: $0.j) } }
}
