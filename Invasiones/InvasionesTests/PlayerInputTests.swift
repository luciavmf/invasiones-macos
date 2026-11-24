//
//  PlayerInputTests.swift
//  InvasionesTests
//
//  How mouse drags and clicks become player intents, and which cursor is shown.
//  The rules are described in docs/specs/selection-and-orders.md.
//

import CoreGraphics
import Testing
@testable import Invasiones

@MainActor
struct PlayerInputTests {

    private let pointer = FakePointer()
    private let map = FakeInputMap()
    private let input: PlayerInput

    private let left = Mouse.Constants.leftButton
    private let right = Mouse.Constants.rightButton

    init() {
        input = PlayerInput(map: map, pointer: pointer)
    }

    private func makeUnit(_ faction: Episode.Faction) -> GameUnit {
        let unit = GameUnit(sound: FakeSound())
        unit.faction = faction
        return unit
    }

    // MARK: - Dragging

    @Test func aFinishedDragSelectsInsideItsRectangle() {
        pointer.finishedDragging = true
        pointer.dragRect = CGRect(x: 10, y: 20, width: 30, height: 40)

        #expect(input.dragSelection() == .selectInRect(x: 10, y: 20, w: 30, h: 40))
    }

    @Test func aDragUnderFourPixelsEitherWayIsIgnored() {
        pointer.finishedDragging = true
        pointer.dragRect = CGRect(x: 10, y: 20, width: 30, height: 3)

        #expect(input.dragSelection() == nil)
    }

    @Test func aDragStillInProgressSelectsNothing() {
        pointer.dragging = true
        pointer.dragRect = CGRect(x: 10, y: 20, width: 30, height: 40)

        #expect(input.dragSelection() == nil)
    }

    // MARK: - Left clicks

    @Test func leftClickOnAnArgentineUnitSelectsIt() {
        let unit = makeUnit(.argentine)
        pointer.press(left)

        let intents = input.clickIntents(unitUnderPointer: unit, hasSelection: false)

        #expect(intents == [.select(unit)])
        #expect(!pointer.pressedButtons.contains(left))
    }

    @Test func leftClickOnAnEnemyWithoutASelectionDoesNothing() {
        pointer.press(left)

        let intents = input.clickIntents(unitUnderPointer: makeUnit(.enemy), hasSelection: false)

        #expect(intents.isEmpty)
    }

    @Test func leftClickElsewhereDeselects() {
        pointer.press(left)

        #expect(input.clickIntents(unitUnderPointer: nil, hasSelection: true) == [.deselect])
        #expect(input.clickIntents(unitUnderPointer: makeUnit(.enemy), hasSelection: true) == [.deselect])
    }

    @Test func holdingTheButtonWhileDraggingARectangleIsNotAClick() {
        pointer.press(left)
        pointer.dragging = true
        pointer.dragRect = CGRect(x: 0, y: 0, width: 10, height: 10)

        let intents = input.clickIntents(unitUnderPointer: makeUnit(.argentine), hasSelection: true)

        #expect(intents.isEmpty)
    }

    // MARK: - Right clicks

    @Test func rightClickOnAWalkableTileMovesThere() {
        pointer.press(right)

        let intents = input.clickIntents(unitUnderPointer: nil, hasSelection: true)

        #expect(intents == [.move(x: 3, y: 4)])
        #expect(pointer.pressedButtons.isEmpty)
    }

    @Test func rightClickOnALiveEnemyAttacksIt() {
        let enemy = makeUnit(.enemy)
        pointer.press(right)

        #expect(input.clickIntents(unitUnderPointer: enemy, hasSelection: true) == [.attack(enemy)])
    }

    @Test func rightClickOnADeadEnemyOrAnOwnUnitMovesThere() {
        let dead = makeUnit(.enemy)
        dead.takeDamage(1_000)

        pointer.press(right)
        #expect(input.clickIntents(unitUnderPointer: dead, hasSelection: true) == [.move(x: 3, y: 4)])

        pointer.press(right)
        #expect(input.clickIntents(unitUnderPointer: makeUnit(.argentine), hasSelection: true)
                == [.move(x: 3, y: 4)])
    }

    @Test func rightClickOnAnInfirmaryHealsThere() {
        map.walkable = false
        map.infirmary = true
        pointer.press(right)

        #expect(input.clickIntents(unitUnderPointer: nil, hasSelection: true) == [.heal(x: 3, y: 4)])
    }

    @Test func rightClickOnAnotherBlockedTileIsUsedUpWithoutAnOrder() {
        map.walkable = false
        pointer.press(right)

        #expect(input.clickIntents(unitUnderPointer: nil, hasSelection: true).isEmpty)
        #expect(pointer.pressedButtons.isEmpty)
    }

    @Test func rightClickWithoutASelectionIsLeftAlone() {
        pointer.press(right)

        #expect(input.clickIntents(unitUnderPointer: nil, hasSelection: false).isEmpty)
        #expect(pointer.pressedButtons == [right])
    }

    @Test func selectingAndOrderingInTheSameFrame() {
        let unit = makeUnit(.argentine)
        pointer.press(left)
        pointer.press(right)

        let intents = input.clickIntents(unitUnderPointer: unit, hasSelection: false)

        #expect(intents == [.select(unit), .move(x: 3, y: 4)])
    }

    // MARK: - Cursor

    @Test func cursorIsNormalWithoutASelection() {
        map.infirmary = true

        #expect(input.cursor(unitUnderPointer: makeUnit(.enemy), hasSelection: false,
                             selectionNeedsHealing: true) == .normal)
    }

    @Test func cursorShowsAnAttackOverAnEnemy() {
        #expect(input.cursor(unitUnderPointer: makeUnit(.enemy), hasSelection: true,
                             selectionNeedsHealing: false) == .attack)
        #expect(input.cursor(unitUnderPointer: makeUnit(.argentine), hasSelection: true,
                             selectionNeedsHealing: false) == .normal)
    }

    @Test func cursorShowsHealingOverAnInfirmaryOnlyForAHurtSelection() {
        map.infirmary = true

        #expect(input.cursor(unitUnderPointer: nil, hasSelection: true,
                             selectionNeedsHealing: true) == .heal)
        #expect(input.cursor(unitUnderPointer: nil, hasSelection: true,
                             selectionNeedsHealing: false) == .normal)
    }
}
