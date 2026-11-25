//
//  PlayerInput.swift
//  Invasiones
//
//  Turns the mouse into player intents and picks the cursor.
//  The rules are described in docs/specs/selection-and-orders.md.
//

internal import CoreGraphics

/// What player input needs from the map.
protocol InputMap: WalkableGrid {
    /// The map tile and the physical tile (2× resolution) under a screen point.
    func tiles(atScreenX x: Int, y: Int) -> (tile: (x: Int, y: Int), physicalTile: (x: Int, y: Int))
    /// Whether a map tile is part of an infirmary.
    func isInfirmary(x: Int, y: Int) -> Bool
}

extension Map: InputMap {}

/// Reads the pointer for the Argentine team: drags and clicks become `PlayerIntent`s,
/// and the cursor shows what a right click would do.
final class PlayerInput {

    /// The cursor shapes used in battle.
    enum Cursor {
        case normal
        /// Over an enemy, with a selection: a right click attacks.
        case attack
        /// Over an infirmary, with a hurt selection: a right click heals.
        case heal
    }

    /// A drag only counts when it is at least this many pixels in both directions.
    static let minimumDragSize = 4

    private let map: any InputMap
    private let pointer: any PointerDevice
    /// Where the cursor images come from.
    private let resources: ResourceManager

    init(map: any InputMap, pointer: any PointerDevice = Mouse.shared,
         resources: ResourceManager = .shared) {
        self.map = map
        self.pointer = pointer
        self.resources = resources
    }

    /// The pointer's position in screen coordinates.
    var position: (x: Int, y: Int) { (Int(pointer.x), Int(pointer.y)) }

    /// A drag that ended this frame selects the units inside it.
    func dragSelection() -> PlayerIntent? {
        // Fire on the frame the drag ends (matches original C# TerminoDeArrastrar() check).
        guard pointer.didFinishDragging() else { return nil }
        let rect = pointer.dragRect
        guard Int(rect.width) >= Self.minimumDragSize && Int(rect.height) >= Self.minimumDragSize else { return nil }
        return .selectInRect(x: Int(rect.origin.x), y: Int(rect.origin.y),
                             w: Int(rect.width), h: Int(rect.height))
    }

    /// Left clicks select or deselect; right clicks give the selection an order.
    /// Handled clicks are released, so they aren't read again next frame.
    func clickIntents(unitUnderPointer: Unit?, hasSelection: Bool) -> [PlayerIntent] {
        var intents: [PlayerIntent] = []
        var willHaveSelection = hasSelection

        // Left click on an Argentine unit: select it.
        if isClicking(Mouse.Constants.leftButton),
           let unit = unitUnderPointer, unit.faction == .argentine {
            intents.append(.select(unit))
            willHaveSelection = true
            pointer.releaseButton(Mouse.Constants.leftButton)
        }

        // Without a selection, right clicks are left alone.
        guard willHaveSelection else { return intents }

        // Right click: attack, move or heal.
        if pointer.pressedButtons.contains(Mouse.Constants.rightButton) {
            pointer.releaseButton(Mouse.Constants.rightButton)
            if let order = order(unitUnderPointer: unitUnderPointer) {
                intents.append(order)
            }
        }

        // Left click anywhere else: deselect.
        if isClicking(Mouse.Constants.leftButton) {
            intents.append(.deselect)
        }
        return intents
    }

    /// The cursor for the current pointer position.
    func cursor(unitUnderPointer: Unit?, hasSelection: Bool, selectionNeedsHealing: Bool) -> Cursor {
        guard hasSelection else { return .normal }
        let tile = map.tiles(atScreenX: position.x, y: position.y).tile
        if selectionNeedsHealing && map.isInfirmary(x: tile.x, y: tile.y) { return .heal }
        if unitUnderPointer?.faction == .enemy { return .attack }
        return .normal
    }

    /// Shows a cursor shape.
    func show(_ cursor: Cursor) {
        let image: ImageID
        switch cursor {
        case .normal: image = .cursor
        case .attack: image = .swordCursor
        case .heal: image = .infirmaryCursor
        }
        pointer.cursor = resources.getImage(image)
    }

    // MARK: - Private

    /// A button held down without dragging a rectangle.
    private func isClicking(_ button: Int) -> Bool {
        guard pointer.pressedButtons.contains(button) else { return false }
        let rect = pointer.dragRect
        let isDraggingARectangle = pointer.isDragging()
            && Int(rect.width) >= Self.minimumDragSize && Int(rect.height) >= Self.minimumDragSize
        return !isDraggingARectangle
    }

    /// The order a right click gives: attack an enemy, move to a walkable tile, or heal at an infirmary.
    private func order(unitUnderPointer: Unit?) -> PlayerIntent? {
        let tiles = map.tiles(atScreenX: position.x, y: position.y)
        let target = tiles.physicalTile

        if map.isWalkable(x: target.x, y: target.y) {
            if let enemy = unitUnderPointer, enemy.faction == .enemy, !enemy.isDead() {
                return .attack(enemy)
            }
            return .move(x: target.x, y: target.y)
        }
        if map.isInfirmary(x: tiles.tile.x, y: tiles.tile.y) {
            return .heal(x: target.x, y: target.y)
        }
        return nil
    }
}
