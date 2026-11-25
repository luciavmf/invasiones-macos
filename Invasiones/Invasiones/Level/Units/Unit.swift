//
//  Unit.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Unidad.cs (multiple partial files merged) — represents a unit in the game.
//

import Foundation

/// Represents a single unit (soldier) in the game.
/// Manages its own state machine (idle, moving, patrolling, attacking, pursuing, healing, dying),
/// pathfinding, formation offsets and collision evasion. `UnitView` draws it.
final class Unit: MapObject {

    // MARK: - Constants
    enum Constants {
        /// Maximum tile radius a unit can see other units.
        static let maxVisibility = 15
        /// Tile radius within which collision checks are performed.
        static let collisionCheckDistance = 4
        /// Minimum number of tiles away a patrol destination can be from the base position.
        static let patrolRandomMin = 8
        /// Maximum number of tiles away a patrol destination can be from the base position.
        static let patrolRandomMax = 16
        /// A unit meets a move objective when it is closer than this many tiles to it on each axis.
        static let minTilesToCompleteMove = 3
        /// Number of ticks the unit's corpse remains visible on screen before disappearing.
        static let deathFrameCount = 150
    }

    // MARK: - Enums
    /// States in which a unit can exist.
    enum State {
        case idle, moving, dying, attacking, pursuingUnit, dead, patrolling, healing
    }

    /// Sub-states used within the moving state.
    enum Substep {
        case incrementStep, dodgeUnit, reachStep, completedStep
    }

    // MARK: - Attributes
    /// The kind of soldier.
    private let type: UnitType
    private var substate: Substep = .incrementStep
    /// The faction this unit belongs to.
    var faction: Episode.Faction = .enemy
    /// The unit currently being evaded after a collision.
    private(set) var unitToEvade: Unit?
    /// Tiles to treat as blocked on the next pathfinder call (set by evadeUnit, consumed by recalculateNextStep).
    private var dodgeBlockedTiles: [(i: Int, j: Int)] = []
    /// Current health points.
    private(set) var health: Int = 100
    /// The stats of the unit's type, read from its CSV file.
    let stats: UnitStats
    private var currentSpeed: (x: Int, y: Int)
    private var enemy: Unit?
    private var stateValue: State = .idle
    private var nextStateValue: State = .idle
    private var direction: Int = 0  // 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SO, 6=O, 7=NO
    /// The remaining path to follow, stored as a stack (popLast = next step).
    private(set) var pathToFollow: [(i: Int, j: Int)]? = nil
    /// The tile the unit is currently moving toward.
    private(set) var nextTile: (x: Int, y: Int) = (0, 0)
    private var nextStep: (x: Int, y: Int) = (0, 0)
    /// Whether the unit is currently selected by the player.
    var isSelected: Bool = false
    private var mode: Int = 0
    /// Draws the unit: its sprite, animation and health bar.
    let view: UnitView
    private var count: Int = 0
    private var targetPos: (x: Int, y: Int)?
    /// The avatar image shown in the HUD when this unit is selected.
    let avatar: Surface?
    private var command: Command?
    /// The objective-level command used to determine whether the unit has fulfilled its mission.
    /// Assigning a new one resets `completedOrder`.
    var objectiveCommand: Command? {
        didSet { completedOrder = false }
    }
    /// Set to `true` when the unit has fulfilled its assigned order this frame.
    private(set) var completedOrder: Bool = false
    /// The base tile position used as the centre of the patrol area.
    private var patrolPosition: (x: Int, y: Int) = (0, 0)
    private var desiredPosition: (x: Int, y: Int) = (0, 0)  // offset en formación
    private var isCommander: Bool = false
    private var group: Group?
    private var completedObjectiveOrder: Bool = false

    // Continuous world position for smooth movement
    private var posX: Double = 0
    private var posY: Double = 0

    // MARK: - Public properties

    var currentState: State { stateValue }
    /// Maximum health points.
    var resistancePoints: Int { stats.resistancePoints }
    /// Damage dealt by each shot (always in full; there is no accuracy roll).
    var attackPoints: Int { stats.attackPoints }
    /// Tile radius within which enemy units are seen.
    var visibility: Int { stats.visibility }
    /// Frames between shots.
    var attackInterval: Int { stats.attackInterval }
    /// Accuracy. Shown in the HUD but never used in combat, as in the original.
    var aim: Int { stats.aim }
    /// The attack range of the unit in tiles.
    var range: Int { stats.attackRange }
    /// The unit's display name.
    var name: String { stats.name }
    /// The current movement speed vector.
    var speed: (x: Int, y: Int) { currentSpeed }
    /// The base movement speed loaded from the unit CSV.
    var defaultSpeed: Int { stats.speed }
    /// The offset within the formation used for flocking/grouping calculations.
    var formationOffset: (x: Int, y: Int) {
        get { desiredPosition }
        set { desiredPosition = newValue }
    }

    // MARK: - Dependencies
    /// Used to compute movement paths. Injectable so tests can use a hand-made grid.
    private let pathFinder: PathFinder
    /// Used for shot and death sounds. Injectable so tests can record calls.
    private let sound: any SoundPlayer

    // MARK: - Initializers

    /// Creates a unit with the given stats, at full health. Tests leave out the battlefield
    /// and the stats; the game uses `init(_:battlefield:)`.
    init(type: UnitType = .patricio, stats: UnitStats = UnitStats(), battlefield: Battlefield? = nil,
         pathFinder: PathFinder = .shared, sound: any SoundPlayer = Sound.shared) {
        self.type = type
        self.stats = stats
        self.pathFinder = pathFinder
        self.sound = sound
        health = stats.resistancePoints
        currentSpeed = (stats.speed, stats.speed)
        avatar = stats.avatar.flatMap { ResourceManager.shared.getImage($0) }
        view = UnitView(sprite: stats.sprite
            .flatMap { ResourceManager.shared.sprites[$0] }
            .map { Sprite(copia: $0) })
        super.init(battlefield: battlefield)
    }

    /// Creates a unit of the given type, with the stats `ResourceManager` loaded for it.
    convenience init(_ type: UnitType, battlefield: Battlefield,
                     pathFinder: PathFinder = .shared, sound: any SoundPlayer = Sound.shared) {
        let stats = ResourceManager.shared.unitStats[type]
        if stats == nil { Log.shared.debug("Unit stats not loaded: \(type)") }
        self.init(type: type, stats: stats ?? UnitStats(), battlefield: battlefield,
                  pathFinder: pathFinder, sound: sound)
    }

    // MARK: - Main update

    /// Updates the unit. Returns true if it moved on the physical map.
    @discardableResult
    override func update() -> Bool {
        guard stateValue != .dead else { return false }

        var movedOnMap = false
        completedOrder = false

        switch stateValue {
        case .idle:
            break
        case .moving:
            movedOnMap = updateMovingState()
        case .patrolling:
            movedOnMap = updatePatrollingState()
        case .pursuingUnit:
            movedOnMap = updatePursuingUnitState()
        case .attacking:
            updateAttackingState()
        case .dying:
            updateDyingState()
        case .dead:
            break
        case .healing:
            updateHealingState()
        }

        // Check if the objective order was fulfilled
        checkOrderCompleted()

        super.update()
        view.update(state: stateValue, direction: direction)
        return movedOnMap
    }

    override func updateScreenPos() {
        guard let cam = battlefield?.camera, let map = battlefield?.map else { return }
        x = cam.startX + worldPos.x + cam.x + map.tileWidth / 2
        y = cam.startY + worldPos.y + cam.y + map.tileHeight / 4
    }

    override func draw(_ video: Video) {
        let healthLeft = Double(health) / Double(max(resistancePoints, 1))
        view.draw(video, x: x, y: y, health: isSelected ? healthLeft : nil)
    }

    // MARK: - Public orders

    /// Orders the unit to move to tile (x, y), computing a path via A*.
    func move(x: Int, y: Int) {
        command = Command(.move, x, y)
        setState(.moving)
        nextStateValue = .idle

        let path = pathFinder.findShortestPath(
            startI: physicalTilePos.x, startJ: physicalTilePos.y, targetI: x, targetJ: y)

        if let c = path, !c.isEmpty {
            // First element is destination, last is origin. Used as a stack (popLast = next step).
            pathToFollow = Array(c.dropLast())   // quita el nodo start (último = origen)
        } else {
            setState(.idle)
            pathToFollow = nil
            return
        }

        substate = .incrementStep
    }

    /// Puts the unit into patrol mode, wandering randomly around its starting tile.
    func patrol() {
        setState(.patrolling)
        nextStateValue = .patrolling
        patrolPosition = physicalTilePos
        pathToFollow = findRandomPatrolPath(
            i: physicalTilePos.x, j: physicalTilePos.y)
    }

    /// Orders the unit to pursue and attack the given enemy unit.
    func attack(enemy: Unit) {
        self.enemy = enemy
        targetPos = nil
        setState(.pursuingUnit)
    }

    /// Halts the unit immediately, clearing its path and returning it to idle.
    func stop() {
        setState(.idle)
        pathToFollow = nil
    }

    /// Puts the unit into the healing state so it regenerates health over time.
    func recoverHealth() {
        setState(.healing)
    }

    // MARK: - Collision and evasion

    /// Returns `true` if this unit's next step lands on the same tile as `other`.
    /// Mirrors C# Unidad.HayColision: collision only when our next tile equals their
    /// current resting tile (stationary) or their next tile (moving). Proximity alone
    /// is not a collision — otherwise any nearby unit would trigger evade every frame
    /// and movement would lock up.
    func hasCollision(_ other: Unit) -> Bool {
        guard other !== self else { return false }
        if other.isMoving() {
            return nextTile.x == other.nextTile.x && nextTile.y == other.nextTile.y
        } else {
            return nextTile.x == other.physicalTilePos.x && nextTile.y == other.physicalTilePos.y
        }
    }

    /// Triggers the evasion sub-state so the unit recalculates its path around `other`.
    /// Captures nearby unit tiles so the next A* call routes around them.
    func evadeUnit(other: Unit, visible: [Unit]?) {
        unitToEvade = other
        substate = .dodgeUnit

        var blocked: [(i: Int, j: Int)] = []
        for u in visible ?? [] {
            let tile = u.isMoving() ? u.nextTile : u.physicalTilePos
            blocked.append((tile.x, tile.y))
        }
        dodgeBlockedTiles = blocked
    }

    // MARK: - Queries

    /// Returns `true` if the unit is dead or in the dying animation.
    func isDead() -> Bool { stateValue == .dead || stateValue == .dying }

    /// Returns `true` if the unit is in any active movement state (moving, patrolling, or pursuing).
    func isMoving() -> Bool {
        return stateValue == .moving || stateValue == .patrolling || stateValue == .pursuingUnit
    }

    /// Returns `true` if the unit's screen position falls within the camera's visible area.
    func isOnScreen() -> Bool {
        guard let cam = battlefield?.camera else { return false }
        return x >= cam.startX && x <= cam.startX + cam.width &&
               y >= cam.startY && y <= cam.startY + cam.height
    }

    /// Calculates the Euclidean distance in tile units from this unit to tile (toI, toJ).
    func calculateDistance(toI: Int, toJ: Int) -> Double {
        let di = Double(physicalTilePos.x - toI)
        let dj = Double(physicalTilePos.y - toJ)
        return sqrt(di * di + dj * dj)
    }

    /// Returns `true` if the unit is close enough to its objective tile to count the MOVE order as fulfilled:
    /// closer than `minTilesToCompleteMove` tiles on each axis, as in the original.
    func completedMoveObjective() -> Bool {
        guard let ord = objectiveCommand else { return false }
        return abs(ord.point.x - physicalTilePos.x) < Constants.minTilesToCompleteMove
            && abs(ord.point.y - physicalTilePos.y) < Constants.minTilesToCompleteMove
    }

    // MARK: - Group / formation

    /// Returns `true` if the unit currently belongs to a group.
    var belongsToGroup: Bool { group != nil }
    /// The group this unit belongs to, or `nil` if it is operating independently.
    var myGroup: Group? { group }

    /// Registers this unit as a member of `group`.
    func joinGroup(_ group: Group) {
        self.group = group
    }

    /// Removes this unit from its current group.
    func leaveGroup() {
        group = nil
    }

    /// Marks this unit as the group commander (its path determines group movement).
    func markAsCommander() {
        isCommander = true
    }

    /// Removes the commander designation from this unit.
    func unmarkCommander() {
        isCommander = false
    }

    /// Calculates this unit's path by offsetting the commander's path by (offsetX, offsetY) tiles,
    /// finding detours through A* for any non-walkable positions.
    /// - Parameters:
    ///   - commanderPath: The path the group commander is following.
    ///   - offsetX: Formation tile offset along the i axis.
    ///   - offsetY: Formation tile offset along the j axis.
    func calculatePathAtDistance(commanderPath: [(i: Int, j: Int)],
                                 offsetX: Int, offsetY: Int) {
        guard let map = battlefield?.map else { return }

        setState(.moving)
        nextStateValue = .idle

        // Build offset copy of commander's path.
        // commanderPath: [0]=destination, [last]=first step (Swift format).
        // Iterate reversed so pathCopy[0]=first step, ..., [last]=destination (same order as C# Stack).
        let pathCopy: [(i: Int, j: Int)] = commanderPath.reversed().map { (i: $0.i + offsetX, j: $0.j + offsetY) }

        var pathList: [(i: Int, j: Int)] = []
        var idx = 0

        while idx < pathCopy.count {
            let point = pathCopy[idx]
            if !map.isWalkable(x: point.i, y: point.j) {
                if idx > 0 {
                    let prevIdx = idx - 1
                    guard let nextValidIdx = findNextValidPosition(pathCopy, from: idx) else {
                        // No more valid points ahead — stop here
                        idx = pathCopy.count
                        continue
                    }
                    idx = nextValidIdx

                    var newPath = pathFinder.findShortestPath(
                        startI: pathCopy[prevIdx].i, startJ: pathCopy[prevIdx].j,
                        targetI: pathCopy[idx].i,    targetJ: pathCopy[idx].j)

                    if newPath == nil {
                        guard let prevValidIdx = findPrevValidPosition(pathCopy, from: nextValidIdx) else {
                            Log.shared.debug("Unit: no valid path found.")
                            pathToFollow = []
                            return
                        }
                        idx = prevValidIdx
                        newPath = pathFinder.findShortestPath(
                            startI: pathCopy[prevIdx].i, startJ: pathCopy[prevIdx].j,
                            targetI: pathCopy[idx].i,    targetJ: pathCopy[idx].j)
                    }

                    guard let segment = newPath else {
                        pathToFollow = []
                        return
                    }
                    // segment: [0]=destination, [last]=origin — append in Pop order (reversed)
                    pathList.append(contentsOf: segment.reversed())
                } else {
                    idx += 1
                }
            } else {
                pathList.append(point)
                idx += 1
            }
        }

        // pathList is first-step→destination; store as Swift path array ([0]=destination, [last]=first-step)
        pathToFollow = pathList.reversed()
        substate = .incrementStep
    }

    private func findNextValidPosition(_ list: [(i: Int, j: Int)], from start: Int) -> Int? {
        guard let map = battlefield?.map else { return nil }
        var idx = start
        while idx < list.count, !map.isWalkable(x: list[idx].i, y: list[idx].j) {
            idx += 1
        }
        if idx >= list.count { return nil }
        // Skip up to two extra steps, same as C# logic
        if idx < list.count - 1 {
            let next = list[idx + 1]
            if map.isWalkable(x: next.i, y: next.j) {
                idx += 1
                if idx < list.count - 1 {
                    let next2 = list[idx + 1]
                    if map.isWalkable(x: next2.i, y: next2.j) {
                        idx += 1
                    }
                }
            }
        }
        return idx
    }

    private func findPrevValidPosition(_ list: [(i: Int, j: Int)], from start: Int) -> Int? {
        guard let map = battlefield?.map else { return nil }
        var idx = start
        while idx >= 0, !map.isWalkable(x: list[idx].i, y: list[idx].j) {
            idx -= 1
        }
        if idx < 0 { return nil }
        return idx
    }

    /// Returns `true` if the screen point (mx, my) is inside this unit's sprite bounding box.
    func isUnder(x mx: Int, y my: Int) -> Bool {
        view.contains(px: mx, py: my, x: x, y: y)
    }

    /// Orders the unit to move toward the infirmary at (x, y) and then heal.
    func heal(x: Int, y: Int) {
        command = Command(.heal, x, y)

        guard let map = battlefield?.map else { return }
        guard let p = map.getLineOfSightPosition(x1: x, x2: physicalTilePos.x, y1: y, y2: physicalTilePos.y) else {
            Log.shared.debug("Unit: cannot send to heal.")
            return
        }
        setHealing(x: p.x, y: p.y)
    }

    private func setHealing(x: Int, y: Int) {
        setState(.moving)
        nextStateValue = .healing

        let path = pathFinder.findShortestPath(
            startI: physicalTilePos.x, startJ: physicalTilePos.y, targetI: x, targetJ: y)

        if let c = path, !c.isEmpty {
            pathToFollow = Array(c.dropLast())
        } else {
            Log.shared.debug("Unit: no path found to heal location.")
            setState(.idle)
            pathToFollow = nil
            return
        }
        substate = .incrementStep
    }

    // MARK: - Drag-rectangle selection
    /// Selects the unit if its sprite is inside the drag-selection rectangle.
    /// - Parameters:
    ///   - rectX: Left edge of the rectangle, in screen coordinates.
    ///   - rectY: Top edge of the rectangle, in screen coordinates.
    /// - Returns: `true` if the unit was selected.
    func selectIfInRect(x rectX: Int, y rectY: Int, w: Int, h: Int) -> Bool {
        let inRange = view.isCovered(byRectX: rectX, y: rectY, w: w, h: h, x: x, y: y)
        if inRange { isSelected = true }
        return inRange
    }

    // MARK: - Private

    private func setState(_ e: State) {
        stateValue = e
        count = 0
        if e == .idle {
            pathToFollow = nil
        }
        if e == .attacking {
            enemy?.counterAttack(self)
        }
    }

    /// Called when this unit starts being attacked. If idle and in range, counter-attacks.
    func counterAttack(_ attacker: Unit) {
        guard stateValue == .idle else { return }
        Log.shared.debug("Unit: under attack, counter-attacking.")
        enemy = attacker
        if calculateDistance(toI: attacker.physicalTilePos.x, toJ: attacker.physicalTilePos.y) < Double(stats.attackRange) {
            aimAtUnit(attacker)
            setState(.attacking)
        }
    }

    // MARK: - Movement

    private func updateMovingState() -> Bool {
        return moverse()
    }

    private func updatePatrollingState() -> Bool {
        if pathToFollow == nil {
            pathToFollow = findRandomPatrolPath(i: physicalTilePos.x, j: physicalTilePos.y)
        }
        return moverse()
    }

    private func moverse() -> Bool {
        switch substate {
        case .incrementStep:
            guard let path = pathToFollow, !path.isEmpty else {
                setState(nextStateValue)
                pathToFollow = nil
                return false
            }
            nextTile = (path.last!.i, path.last!.j)
            pathToFollow!.removeLast()
            nextStep = tileToWorld(i: nextTile.x, j: nextTile.y)
            substate = .reachStep

        case .dodgeUnit:
            recalculateNextStep()
            substate = .reachStep
            return true

        default: break
        }

        if let dir = getDirection(targetX: nextStep.x, targetY: nextStep.y) { direction = dir }

        let arrived = moveToNextStep()

        if arrived {
            let prevTile = physicalTilePos
            previousTile = prevTile
            physicalTilePos = nextTile
            substate = .incrementStep
            return true
        }
        return false
    }

    /// Moves one step toward nextStep using Euclidean normalization.
    /// Direction-based per-axis velocity (C# parity) is not used here because in the isometric
    /// coordinate system adjacent tiles have unequal dx/dy (e.g. SE tile: dx=+16, dy=+8),
    /// so applying equal vx/vy per direction overshoots the shorter axis and causes visual jitter.
    private func moveToNextStep() -> Bool {
        let spd = stats.speed

        let dx = nextStep.x - worldPos.x
        let dy = nextStep.y - worldPos.y
        let dist = sqrt(Double(dx * dx + dy * dy))

        if dist <= Double(spd) {
            worldPos = nextStep
            // Keep currentSpeed consistent for any callers that read it.
            currentSpeed = (dx, dy)
            return true
        }

        let ratio = Double(spd) / dist
        let vx = Int(Double(dx) * ratio)
        let vy = Int(Double(dy) * ratio)
        currentSpeed = (vx, vy)
        worldPos.x += vx
        worldPos.y += vy
        return false
    }

    private func recalculateNextStep() {
        // Snap back to the current tile (undo partial movement toward the blocked step).
        worldPos = tileToWorld(i: physicalTilePos.x, j: physicalTilePos.y)
        unitToEvade = nil

        let blocked = dodgeBlockedTiles
        dodgeBlockedTiles = []

        guard pathToFollow != nil, !pathToFollow!.isEmpty else {
            setLastPosition()
            return
        }

        // Pop the tile we were heading to (now blocked) and find a detour.
        var nextTileIJ = pathToFollow!.removeLast()

        var newPath = pathFinder.findShortestPath(
            startI: physicalTilePos.x, startJ: physicalTilePos.y,
            targetI: nextTileIJ.i, targetJ: nextTileIJ.j,
            blockedTiles: blocked)

        // If no path, keep popping further waypoints until one is reachable.
        while newPath == nil {
            guard pathToFollow != nil, !pathToFollow!.isEmpty else {
                Log.shared.debug("Unit: no alternative path found.")
                setLastPosition()
                return
            }
            nextTileIJ = pathToFollow!.removeLast()
            newPath = pathFinder.findShortestPath(
                startI: physicalTilePos.x, startJ: physicalTilePos.y,
                targetI: nextTileIJ.i, targetJ: nextTileIJ.j,
                blockedTiles: blocked)
        }

        // newPath: [last] = first step toward nextTileIJ, [0] = nextTileIJ.
        var detour = newPath!
        let primerPaso = detour.removeLast()          // consume first step
        nextTile = (primerPaso.i, primerPaso.j)
        nextStep = tileToWorld(i: nextTile.x, j: nextTile.y)

        // Prepend remaining detour steps before the original remaining path
        // (equivalent to PathFinder.AdherirCamino in C#).
        pathToFollow = (pathToFollow ?? []) + detour
    }

    private func setLastPosition() {
        nextTile = physicalTilePos
        nextStep = tileToWorld(i: nextTile.x, j: nextTile.y)
    }

    private func getDirection(targetX: Int, targetY: Int) -> Int? {
        let dx = targetX - worldPos.x
        let dy = targetY - worldPos.y
        if dx == 0 && dy == 0 { return nil }

        let angle = atan2(Double(dy), Double(dx)) * 180.0 / Double.pi
        // SpriteKit Y is flipped vs game-world Y; map to 8 compass dirs
        let normalized = angle < 0 ? angle + 360 : angle
        let index = Int((normalized + 22.5) / 45.0) % 8
        // angle=0 → E=2, 45 → SE=3, 90 → S=4, 135 → SO=5, 180 → O=6, 225 → NO=7, 270 → N=0, 315 → NE=1
        let mapping = [2, 3, 4, 5, 6, 7, 0, 1]
        return mapping[index]
    }

    // MARK: - Patrolling

    private func findRandomPatrolPath(i: Int, j: Int) -> [(i: Int, j: Int)]? {
        guard let map = battlefield?.map else { return nil }
        let range = Constants.patrolRandomMax - Constants.patrolRandomMin
        // Mirror original C#: loop until a valid path is found.
        // Use the stored patrol base position as the destination origin (not current pos).
        var path: [(i: Int, j: Int)]? = nil
        var attempts = 0
        while path == nil && attempts < 20 {
            attempts += 1
            let offI = Int.random(in: 0..<range) + Constants.patrolRandomMin
            let offJ = Int.random(in: 0..<range) + Constants.patrolRandomMin
            let signI = Bool.random() ? 1 : -1
            let signJ = Bool.random() ? 1 : -1
            let destI = patrolPosition.x + signI * offI
            let destJ = patrolPosition.y + signJ * offJ
            guard map.isWalkable(x: destI, y: destJ) else { continue }
            path = pathFinder.findShortestPath(startI: i, startJ: j, targetI: destI, targetJ: destJ)
        }
        return path
    }

    // MARK: - Pursuit and attack

    /// Chases the enemy: the path is recalculated whenever it changes tile, and the unit
    /// starts shooting once closer than its range. Returns true if the unit moved to a new tile.
    private func updatePursuingUnitState() -> Bool {
        guard let enemy = enemy else {
            setState(.idle)
            return false
        }
        if enemy.isDead() {
            self.enemy = nil
            setState(.idle)
            return false
        }

        nextStateValue = .attacking
        var moved = false

        if targetPos.map({ $0 != enemy.physicalTilePos }) ?? true {
            targetPos = enemy.physicalTilePos
            let path = pathFinder.findShortestPath(
                startI: physicalTilePos.x, startJ: physicalTilePos.y,
                targetI: enemy.physicalTilePos.x, targetJ: enemy.physicalTilePos.y)
            guard let c = path, !c.isEmpty else {
                setState(.idle)
                return false
            }
            pathToFollow = Array(c.dropLast())   // the last node is the start
            substate = .incrementStep
        }

        if calculateDistance(toI: enemy.physicalTilePos.x, toJ: enemy.physicalTilePos.y) < Double(stats.attackRange) {
            aimAtUnit(enemy)
            setState(.attacking)
        } else {
            moved = moverse()
        }

        return moved
    }

    /// Shoots the enemy every `attackInterval` frames, following it while it stays in range
    /// and chasing it when it leaves.
    private func updateAttackingState() {
        guard let enemy = enemy else {
            setState(.idle)
            return
        }
        if enemy.isDead() {
            self.enemy = nil
            setState(.idle)
            return
        }

        // If the enemy moved, aim again, or chase it if it's out of range.
        if targetPos.map({ $0 != enemy.physicalTilePos }) ?? true {
            if calculateDistance(toI: enemy.physicalTilePos.x, toJ: enemy.physicalTilePos.y) < Double(stats.attackRange) {
                aimAtUnit(enemy)
                targetPos = enemy.physicalTilePos
            } else {
                setState(.pursuingUnit)
                nextStateValue = .attacking
            }
        }

        // The original compares before counting, so a shot comes one frame after the interval.
        let ready = count >= attackInterval
        count += 1
        guard ready else { return }

        playShotSound()
        count = 0
        enemy.takeDamage(attackPoints)
        if enemy.isDead() {
            self.enemy = nil
            setState(.idle)
        }
    }

    private func aimAtUnit(_ enemy: Unit) {
        self.enemy = enemy
        let di = enemy.physicalTilePos.x - physicalTilePos.x
        let dj = enemy.physicalTilePos.y - physicalTilePos.y
        // Convertir di/dj a dirección de sprite (8 dirs)
        let angle = atan2(Double(dj), Double(di)) * 180.0 / Double.pi
        let normalized = angle < 0 ? angle + 360 : angle
        let index = Int((normalized + 22.5) / 45.0) % 8
        let mapping = [2, 3, 4, 5, 6, 7, 0, 1]
        direction = mapping[index]
    }

    /// Applies `danio` points of damage to this unit, triggering death if health reaches zero.
    func takeDamage(_ danio: Int) {
        health -= danio
        if health <= 0 {
            health = 0
            morir()
        }
    }

    /// Transitions the unit into the dying state.
    func morir() {
        Log.shared.debug("Unit: died.")
        setState(.dying)
        enemy = nil
    }

    /// The unit is dead after `deathFrameCount` frames (its view plays the death animation once).
    private func updateDyingState() {
        if count == 0 {
            // The original plays the Patricio's death sound for every unit, British ones included.
            sound.play(id: .patricioDeath, loop: 0)
        }

        if count >= Constants.deathFrameCount {
            setState(.dead)
            return
        }
        count += 1
    }

    private func playShotSound() {
        let sfx: SoundID = faction == .argentine ? .patricioShot : .britishShot
        sound.play(id: sfx, loop: 0)
    }

    // MARK: - Healing

    /// Recovers `recoveryPoints` health every `ticksPerRecovery` counts until full.
    private func updateHealingState() {
        // The original counts each frame twice (two increments), so recoveries come
        // about twice as often as ticksPerRecovery suggests.
        count += 1
        let due = count > stats.ticksPerRecovery
        count += 1
        guard due else { return }

        count = 0
        health += stats.recoveryPoints
        if health >= resistancePoints {
            health = resistancePoints
            setState(.idle)
        }
    }

    // MARK: - Check objective order

    private func checkOrderCompleted() {
        guard let ord = objectiveCommand else { return }
        if ord.id == .move || ord.id == .takeObject {
            if completedMoveObjective() {
                completedOrder = true
            }
        }
    }
}
