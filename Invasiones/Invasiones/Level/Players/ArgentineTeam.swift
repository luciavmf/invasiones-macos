//
//  ArgentineTeam.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of BandoArgentino.cs — player-controlled faction.
//

import Foundation

/// The player-controlled Argentine faction.
/// Carries out the player's intents (read by `PlayerInput`): unit selection, group creation,
/// movement, attack and heal orders. Also handles the orientation arrow and objective progress.
final class ArgentineTeam: Player {

    // MARK: - Attributes
    private var unitUnderPointer: Unit?
    private var count: Int = 0
    private var arrowObj: MapObject?
    private var orientationArrow: Animation?
    private var commandTargetPos: (x: Int, y: Int) = (0, 0)
    private var arrowPos: (x: Int, y: Int) = (0, 0)
    private var unitToFindIdx: Int = 0
    private let input: PlayerInput

    private let arrowMaxCount = 100

    // MARK: - Initializer
    init(map: Map, camera: Camera, objectsToDraw: ObjectTable, hud: Hud,
         pointer: any PointerDevice = Mouse.shared) {
        input = PlayerInput(map: map, pointer: pointer)
        super.init(map: map, camera: camera, objectsToDraw: objectsToDraw, hud: hud)
        faction = .argentine

        let anims = ResourceManager.shared.animations
        if let animAros = anims[.rings] {
            ring = AnimObject(Animation(copia: animAros), 0, 0, battlefield: battlefield)
        }

        if let animFlecha = anims[.guideArrow] {
            orientationArrow = Animation(copia: animFlecha)
            try? orientationArrow?.load()
        }
    }

    // MARK: - Override

    override func update() {
        switch stateValue {
        case .start: stateValue = .loading
        case .loading: stateValue = .game
        case .game: updateGameplayState()
        }
    }

    override func loadUnits(_ levelIndex: Int) throws {
        arrowObj = MapObject(sup: ResourceManager.shared.getImage(.arrow),
                               i: 0, j: 0, battlefield: battlefield)
        count = 99999

        guard let unitsTileset = map.tilesets.compactMap({ $0 }).first(where: {
            $0.id == .units
        }) else { return }

        units = []

        for i in 0..<map.width {
            for j in 0..<map.height {
                let tileId = map.unitsLayer[i][j]
                guard tileId != 0 else { continue }

                let localId = tileId - unitsTileset.firstGid
                guard localId >= 0, localId < unitsTileset.tiles.count,
                      let tile = unitsTileset.tiles[localId],
                      tile.kind == .patricio else { continue }

                let list = placeUnits(type: .patricio, count: tile.count, x: i << 1, y: j << 1)

                if list.count > 1 {
                    if groups == nil { groups = [] }
                    groups!.append(Group(list))
                }
            }
        }
    }

    // MARK: - Draw (called from BattleView)

    /// Draws the destination arrow of the last move order (for 100 frames), the objective
    /// ring, the object to take and the fires. As in the original, they're drawn with the
    /// units, so the fog and the HUD cover them, and the arrow's frames are counted here.
    func drawMarkers(_ video: Video) {
        guard stateValue == .game else { return }

        if count < arrowMaxCount {
            arrowObj?.draw(video)
        }
        count += 1

        ring?.draw(video)
        objectToTake?.draw(video)
        fireEffects?.forEach { $0.draw(video) }
    }

    /// Draws the arrow at the edge of the screen pointing at the objective, when it's off-screen.
    func drawOrientationArrow(_ video: Video) {
        guard stateValue == .game else { return }
        guard command != nil, orientationArrow != nil else { return }
        guard !isObjectiveVisible() else { return }
        orientationArrow?.draw(video: video, x: arrowPos.x, y: arrowPos.y, anchor: [])
    }

    // MARK: - Rendering coordinates for Episode

    /// Calculates the range of tile coordinates that are visible in the current camera view.
    /// Used by Episode to determine which objects to draw each frame.
    /// - Returns: (x, y) of the first tile to draw, (w, h) as the tile count in each dimension.
    func getPaintCoordinates() -> (x: Int, y: Int, w: Int, h: Int) {
        let cam = camera
        let p = calculateFirstTileToDraw(x: cam.x, y: cam.y)
        let tw = map.physicalTileWidth > 0 ? map.physicalTileWidth : 1
        let th = map.physicalTileHeight > 0 ? map.physicalTileHeight : 1
        let w = (cam.width - cam.startX) / tw + 23
        let h = ((cam.height - cam.startY) / th) * 2 + 78
        return (p.x - 15, p.y - 5, w, h)
    }

    /// Selects the next Argentine unit in sequence and centers the camera on it.
    func selectNextUnit() {
        guard !units.isEmpty else { return }

        // Center camera on the unit
        let u = units[unitToFindIdx]
        camera.x = (((u.physicalTilePos.y - u.physicalTilePos.x) *
                        map.physicalTileWidth) >> 1) + Video.width / 2
        camera.y = ((-(u.physicalTilePos.y + u.physicalTilePos.x) *
                        map.physicalTileHeight) >> 1) + Video.height / 2

        selectedUnit?.isSelected = false
        selectedGroup?.isSelected  = false

        selectedUnit = u
        selectedUnit?.isSelected = true
        hud.selectedUnit = selectedUnit

        unitToFindIdx += 1
        if unitToFindIdx >= units.count { unitToFindIdx = 0 }
    }

    // MARK: - Private

    private func updateGameplayState() {
        updateOrientationArrow()

        objectToTake?.update()
        ring?.update()

        unitUnderPointer = unitAt(x: input.position.x, y: input.position.y)
        selectedUnits = []

        if let selection = input.dragSelection() { handle(selection) }
        updateUnits()
        input.clickIntents(unitUnderPointer: unitUnderPointer, hasSelection: hasSelection).forEach(handle)

        let hadSelection = hasSelection
        if let unit = selectedUnit, unit.isDead() { clearSelection() }
        input.show(input.cursor(unitUnderPointer: unitUnderPointer, hasSelection: hadSelection,
                                selectionNeedsHealing: selectionNeedsHealing))

        fireEffects?.forEach { $0.update() }
        updateGroups()
        updateObjectives()
        removeDeadUnits()

        arrowObj?.update()
    }

    // MARK: - Orientation arrow

    private func updateOrientationArrow() {
        guard let ord = command, let flecha = orientationArrow else { return }

        // Screen position of the target tile
        commandTargetPos.x = (((ord.point.x - ord.point.y) * map.tileWidth / 2) >> 1)
                              + camera.startX + camera.x
        commandTargetPos.y = (((ord.point.x + ord.point.y) * map.tileHeight  / 2) >> 1)
                              + camera.startY + camera.y

        guard !isObjectiveVisible() else { return }

        let cx = Video.width / 2
        let cy = Video.height  / 2
        let a = Double(commandTargetPos.y - cy)
        let b = Double(commandTargetPos.x - cx)

        var degrees = atan(a / b) * 180 / .pi
        if a < 0 && b > 0  { degrees = -degrees }
        if a >= 0 && b < 0 { degrees = 180 - degrees }
        if a < 0  && b < 0 { degrees = 180 - degrees }
        if a > 0  && b >= 0 { degrees = 360 - degrees }

        let factor = 360.0 / 8
        let half = 360.0 / 16

        let dir: Direction
        if      (degrees >= 0 && degrees < half) || degrees > 360 - half { dir = .east      }
        else if degrees >= half          && degrees < half + factor      { dir = .northEast  }
        else if degrees >= half + factor && degrees < half + factor * 2  { dir = .north      }
        else if degrees >= half + factor * 2 && degrees < half + factor * 3 { dir = .northWest }
        else if degrees >= half + factor * 3 && degrees < half + factor * 4 { dir = .west      }
        else if degrees >= half + factor * 4 && degrees < half + factor * 5 { dir = .southWest }
        else if degrees >= half + factor * 5 && degrees < half + factor * 6 { dir = .south     }
        else                                                                 { dir = .southEast }

        let offset = -20
        let fw = flecha.frameWidth
        let fh = flecha.frameHeight

        if commandTargetPos.x > camera.startX &&
           commandTargetPos.x < camera.width - fw + offset {
            arrowPos.x = commandTargetPos.x
        } else if commandTargetPos.x <= camera.startX {
            arrowPos.x = -offset
        } else {
            arrowPos.x = camera.width - fw + offset
        }

        if commandTargetPos.y > camera.startY &&
           commandTargetPos.y < camera.height - fh + offset {
            arrowPos.y = commandTargetPos.y
        } else if commandTargetPos.y <= camera.startY {
            arrowPos.y = -offset
        } else {
            arrowPos.y = camera.height - fh + offset
        }

        flecha.setAnimation(anim: dir.rawValue)
    }

    private func isObjectiveVisible() -> Bool {
        return commandTargetPos.x > camera.startX &&
               commandTargetPos.x < camera.width   &&
               commandTargetPos.y > camera.startY  &&
               commandTargetPos.y < camera.height
    }

    // MARK: - Unit under the pointer

    /// The unit drawn at a screen point, searching the visible tiles in drawing order.
    private func unitAt(x: Int, y: Int) -> Unit? {
        let rect = getPaintCoordinates()
        var startCol = rect.x, startRow = rect.y
        let endI = rect.w, endJ = rect.h
        var tileY = 0, toggle = true

        while tileY <= endJ {
            var tileX = 0
            var i = startCol, j = startRow
            while tileX <= endI && j >= 0 {
                if i >= 0 && i < map.physicalMapHeight && j < map.physicalMapWidth {
                    if let unit = objectsToDraw.table[i][j] as? Unit,
                       unit.isUnder(x: x, y: y) {
                        return unit
                    }
                }
                tileX += 1
                i += 1
                j -= 1
            }
            tileY += 1
                        if toggle {
                startCol += 1
                toggle = false
            }
                        else {
                startRow += 1
                toggle = true
            }
        }
        return nil
    }

    // MARK: - Intents

    /// Carries out one request from the player.
    func handle(_ intent: PlayerIntent) {
        switch intent {
        case let .selectInRect(x, y, w, h):
            guard selectedUnit == nil && selectedGroup == nil else { return }
            for unit in units where unit.faction == .argentine {
                _ = unit.selectIfInRect(x: x, y: y, w: w, h: h)
            }
            collectSelectedUnits()
            createGroups()

        case let .select(unit):
            guard unit.faction == .argentine else { return }
            clearSelection()
            unit.isSelected = true
            hud.selectedUnit = unit
            selectedUnit = unit
            // A unit picked out of a group leaves it.
            if unit.belongsToGroup {
                unit.myGroup?.removeUnit(unit)
                unit.leaveGroup()
            }

        case .deselect:
            selectedUnits.forEach { $0.isSelected = false }
            clearSelection()

        case let .move(x, y):
            if let group = selectedGroup {
                group.move(x: x, y: y)
            } else {
                selectedUnit?.move(x: x, y: y)
            }
            count = 0
            arrowObj?.setTilePosition(i: x, j: y)

        case let .attack(enemy):
            if let group = selectedGroup {
                group.attack(enemy: enemy)
            } else {
                selectedUnit?.attack(enemy: enemy)
            }

        case let .heal(x, y):
            Log.shared.debug("Unit ordered to heal.")
            if let group = selectedGroup, group.health < group.resistancePoints {
                group.heal(x: x, y: y)
            } else if let unit = selectedUnit, unit.health < unit.resistancePoints {
                unit.heal(x: x, y: y)
            }
        }
    }

    /// Whether a unit or group is selected.
    var hasSelection: Bool { selectedUnit != nil || selectedGroup != nil }

    /// Whether the selected unit or group has lost health, so it can be sent to heal.
    var selectionNeedsHealing: Bool {
        (selectedUnit.map { $0.health < $0.resistancePoints } ?? false)
            || (selectedGroup.map { $0.health < $0.resistancePoints } ?? false)
    }

    // MARK: - Group creation and management

    private func createGroups() {
        guard !selectedUnits.isEmpty else { return }
        guard selectedGroup == nil && selectedUnit == nil else { return }

        if selectedUnits.count > 1 {
            if groups == nil { groups = [] }

            for unit in selectedUnits {
                if unit.belongsToGroup {
                    unit.myGroup?.removeUnit(unit)
                    unit.leaveGroup()
                }
            }

            let group = Group(selectedUnits)
            group.isSelected = true
            selectedGroup = group
            groups?.append(group)
        } else {
            selectedUnit = selectedUnits[0]
        }
    }

    private func updateGroups() {
        guard let current = groups, !current.isEmpty else { return }

        var toRemove: [Group] = []

        for group in current {
            group.update()
            if group.currentState == .waitingCommand && !group.isSelected {
                toRemove.append(group)
            }
            if group.currentState == .eliminating {
                if group === selectedGroup {
                    selectedGroup = nil
                    if group.soldierCount == 1 {
                        selectedUnit = group.getLastUnit()
                    }
                }
                toRemove.append(group)
            }
        }

        for group in toRemove {
            group.dissolve()
            groups?.removeAll { $0 === group }
        }
    }

    // MARK: - Objectives

    private func updateObjectives() {
        guard someoneCompletedOrder else { return }

        if command?.id == .takeObject {
            objectToTake = nil
        }

        setNextCommand()

        if command == nil {
            objectiveCompleted = true
            Log.shared.debug("Objective completed.")
        }
    }

    // MARK: - Private helpers

    private func calculateFirstTileToDraw(x: Int, y: Int) -> (x: Int, y: Int) {
        let th = map.tileHeight > 0 ? map.tileHeight / 2 : 1
        let tw = map.tileWidth > 0 ? map.tileWidth / 2 : 1
        let a = -y / th
        var b =  x / tw
        if x > 0 { b += 1 }
        return (a - b - 4, a + b - 2)
    }
}
