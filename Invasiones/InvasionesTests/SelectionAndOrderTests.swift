//
//  SelectionAndOrderTests.swift
//  InvasionesTests
//
//  How the Argentine team carries out the player's intents: selecting units and giving orders.
//  The rules are described in docs/specs/selection-and-orders.md.
//

import Testing
@testable import Invasiones

@MainActor
struct SelectionAndOrderTests {

    // Infirmary tiles blocked at the far end of a corridor.
    private let grid = TestGrid(["........##", ".........."])
    private let pathFinder = PathFinder()
    private let camera = Camera(x: 0, y: 0, height: 600)
    private let team: ArgentineTeam

    /// A rectangle that covers every unit on screen.
    private let everything = PlayerIntent.selectInRect(x: -10_000, y: -10_000, w: 20_000, h: 20_000)

    init() {
        pathFinder.load(grid: grid)
        team = ArgentineTeam(map: Map(camera: camera), camera: camera,
                             objectsToDraw: ObjectTable([]), hud: Hud())
    }

    /// Places a unit of the given faction on the first row; Argentine units join the team.
    @discardableResult
    private func addUnit(at j: Int, faction: Episode.Faction = .argentine) -> GameUnit {
        let unit = GameUnit(battlefield: Battlefield(map: grid, camera: camera),
                            pathFinder: pathFinder, sound: FakeSound())
        unit.faction = faction
        unit.setTilePosition(i: 0, j: j)
        if faction == .argentine { team.units.append(unit) }
        return unit
    }

    // MARK: - Drag selection

    @Test func draggingOverOneUnitSelectsIt() {
        let unit = addUnit(at: 0)

        team.handle(everything)

        #expect(team.selectedUnit === unit)
        #expect(team.selectedGroup == nil)
        #expect(unit.isSelected)
    }

    @Test func draggingOverSeveralUnitsFormsASelectedGroup() throws {
        let units = (0..<3).map { addUnit(at: $0) }

        team.handle(everything)

        let group = try #require(team.selectedGroup)
        #expect(team.selectedUnit == nil)
        #expect(group.isSelected)
        #expect(group.soldierCount == 3)
        #expect(units.allSatisfy { $0.isSelected && $0.myGroup === group })
    }

    @Test func dragSelectionStopsAtSixUnits() throws {
        let units = (0..<8).map { addUnit(at: $0) }

        team.handle(everything)

        let group = try #require(team.selectedGroup)
        #expect(group.soldierCount == Player.maxSelectedUnits)
        #expect(units.prefix(6).allSatisfy { $0.isSelected })
        #expect(units.suffix(2).allSatisfy { !$0.isSelected && $0.myGroup == nil })
    }

    @Test func dragSelectionOnlyPicksUnitsInsideTheRectangle() {
        let inside = addUnit(at: 0)
        let outside = addUnit(at: 9)

        // Just around the first unit (sprite 20×30 by default); the other is 144 px to the left.
        team.handle(.selectInRect(x: inside.x - 15, y: inside.y - 20, w: 30, h: 30))

        #expect(team.selectedUnit === inside)
        #expect(!outside.isSelected)
    }

    @Test func dragSelectionIsIgnoredWhileSomethingIsSelected() {
        let first = addUnit(at: 0)
        let second = addUnit(at: 1)
        team.handle(.select(first))

        team.handle(everything)

        #expect(team.selectedUnit === first)
        #expect(!second.isSelected)
    }

    // MARK: - Clicking

    @Test func clickingAUnitSelectsOnlyIt() {
        let first = addUnit(at: 0)
        let second = addUnit(at: 1)
        team.handle(.select(first))

        team.handle(.select(second))

        #expect(team.selectedUnit === second)
        #expect(!first.isSelected)
        #expect(second.isSelected)
    }

    @Test func clickingAUnitTakesItOutOfItsGroup() throws {
        let units = (0..<3).map { addUnit(at: $0) }
        team.handle(everything)
        let group = try #require(team.selectedGroup)

        team.handle(.select(units[0]))

        #expect(team.selectedGroup == nil)
        #expect(team.selectedUnit === units[0])
        #expect(units[0].myGroup == nil)
        #expect(group.soldierCount == 2)
        #expect(!units[1].isSelected)
    }

    @Test func enemyUnitsCannotBeSelected() {
        let enemy = addUnit(at: 0, faction: .enemy)

        team.handle(.select(enemy))

        #expect(team.selectedUnit == nil)
        #expect(!enemy.isSelected)
    }

    @Test func deselectClearsAUnitOrAGroup() {
        let units = (0..<3).map { addUnit(at: $0) }
        team.handle(everything)

        team.handle(.deselect)

        #expect(!team.hasSelection)
        #expect(units.allSatisfy { !$0.isSelected })
        #expect(team.hud.selectedUnit == nil)
    }

    // MARK: - Orders

    @Test func moveSendsTheSelectedUnit() {
        let unit = addUnit(at: 0)
        team.handle(.select(unit))

        team.handle(.move(x: 1, y: 5))

        #expect(unit.currentState == .moving)
        #expect(unit.pathToFollow?.first.map { Point(i: $0.i, j: $0.j) } == Point(i: 1, j: 5))
    }

    @Test func moveSendsTheSelectedGroupIntoFormation() throws {
        (0..<3).forEach { addUnit(at: $0) }
        team.handle(everything)

        team.handle(.move(x: 1, y: 5))

        let group = try #require(team.selectedGroup)
        #expect(group.currentState == .grouping)
    }

    @Test func ordersWithoutASelectionDoNothing() {
        let unit = addUnit(at: 0)
        let enemy = addUnit(at: 5, faction: .enemy)

        team.handle(.move(x: 1, y: 5))
        team.handle(.attack(enemy))

        #expect(unit.currentState == .idle)
    }

    @Test func attackSendsTheUnitAfterTheEnemy() {
        let unit = addUnit(at: 0)
        let enemy = addUnit(at: 5, faction: .enemy)
        team.handle(.select(unit))

        team.handle(.attack(enemy))

        #expect(unit.currentState == .pursuingUnit)
    }

    @Test func attackSendsEveryUnitOfTheGroup() {
        let units = (0..<3).map { addUnit(at: $0) }
        let enemy = addUnit(at: 5, faction: .enemy)
        team.handle(everything)

        team.handle(.attack(enemy))

        #expect(units.allSatisfy { $0.currentState == .pursuingUnit })
    }

    @Test func healOnlySendsHurtUnits() {
        let unit = addUnit(at: 0)
        team.handle(.select(unit))

        team.handle(.heal(x: 0, y: 9))
        #expect(unit.currentState == .idle)

        unit.takeDamage(10)
        team.handle(.heal(x: 0, y: 9))
        #expect(unit.currentState == .moving)
    }
}
