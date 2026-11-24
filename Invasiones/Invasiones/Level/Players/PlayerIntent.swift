//
//  PlayerIntent.swift
//  Invasiones
//
//  What the player asks their team to do, independent of how it was read from the mouse.
//

/// One request from the player to the Argentine team. Tiles are physical tiles (2× map resolution).
enum PlayerIntent {
    /// Select the team's units inside a screen rectangle (a finished drag).
    case selectInRect(x: Int, y: Int, w: Int, h: Int)
    /// Select one of the team's units (a click on it).
    case select(Unit)
    /// Clear the selection (a click elsewhere).
    case deselect
    /// Send the selection to a tile.
    case move(x: Int, y: Int)
    /// Send the selection after an enemy unit.
    case attack(Unit)
    /// Send the selection to heal at the infirmary tile that was clicked.
    case heal(x: Int, y: Int)
}

extension PlayerIntent: Equatable {
    static func == (lhs: PlayerIntent, rhs: PlayerIntent) -> Bool {
        switch (lhs, rhs) {
        case let (.selectInRect(x1, y1, w1, h1), .selectInRect(x2, y2, w2, h2)):
            return (x1, y1, w1, h1) == (x2, y2, w2, h2)
        case let (.select(a), .select(b)), let (.attack(a), .attack(b)):
            return a === b
        case (.deselect, .deselect):
            return true
        case let (.move(x1, y1), .move(x2, y2)), let (.heal(x1, y1), .heal(x2, y2)):
            return (x1, y1) == (x2, y2)
        default:
            return false
        }
    }
}
