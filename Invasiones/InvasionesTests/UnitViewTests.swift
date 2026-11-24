//
//  UnitViewTests.swift
//  InvasionesTests
//
//  Which animation a unit shows, and the hit-tests that use its sprite's size.
//

import Testing
@testable import Invasiones

@MainActor
struct UnitViewTests {

    private let sprite = FakeSprite()
    private let view: UnitView

    init() {
        view = UnitView(sprite: sprite)
    }

    // MARK: - Animation

    @Test(arguments: [
        (GameUnit.State.idle, 0),
        (.healing, 0),
        (.moving, 8),
        (.pursuingUnit, 8),
        (.patrolling, 8),
        (.dying, 16),
        (.attacking, 24),
    ])
    func eachStateShowsItsPackTurnedToTheDirection(state: GameUnit.State, pack: Int) {
        view.update(state: state, direction: 3)

        #expect(sprite.animation == pack + 3)
        #expect(sprite.isPlaying)
    }

    @Test func theAnimationAdvancesOncePerFrame() {
        for _ in 0..<5 { view.update(state: .idle, direction: 0) }

        #expect(sprite.advances == 5)
    }

    @Test func turningChangesTheAnimation() {
        view.update(state: .moving, direction: 2)
        view.update(state: .moving, direction: 6)

        #expect(sprite.animation == 8 + 6)
    }

    @Test func dyingPlaysOnceThenHoldsTheLastFrame() {
        view.update(state: .attacking, direction: 4)
        view.update(state: .dying, direction: 4)
        #expect(sprite.animation == 16 + 4)
        #expect(!sprite.loop)
        #expect(sprite.isPlaying)

        sprite.animationDone = true
        view.update(state: .dying, direction: 4)

        #expect(sprite.frame == sprite.frameCount - 1)
        #expect(!sprite.isPlaying)
    }

    @Test func aViewWithoutASpriteDoesNothing() {
        let view = UnitView(sprite: nil)

        view.update(state: .dying, direction: 0)

        #expect(view.size == (20, 30))
    }

    // MARK: - Hit-tests

    // The sprite is 24×40 and the unit's feet are at (100, 200):
    // it covers x 88...112 and y 160...200.

    @Test func aPointOnTheSpriteIsOnTheUnit() {
        #expect(view.contains(px: 100, py: 180, x: 100, y: 200))
        #expect(view.contains(px: 88, py: 160, x: 100, y: 200))
        #expect(view.contains(px: 112, py: 200, x: 100, y: 200))
    }

    @Test func aPointOffTheSpriteIsNot() {
        #expect(!view.contains(px: 87, py: 180, x: 100, y: 200))
        #expect(!view.contains(px: 100, py: 159, x: 100, y: 200))
        #expect(!view.contains(px: 100, py: 201, x: 100, y: 200))
    }

    @Test func aRectangleMustCoverTheFullWidthAndTheLowerHalf() {
        // From the middle of the sprite (y 180) to below the feet.
        #expect(view.isCovered(byRectX: 88, y: 180, w: 25, h: 21, x: 100, y: 200))
        // Too narrow on the right.
        #expect(!view.isCovered(byRectX: 88, y: 180, w: 24, h: 21, x: 100, y: 200))
        // Starts below the middle.
        #expect(!view.isCovered(byRectX: 88, y: 181, w: 25, h: 21, x: 100, y: 200))
        // Ends at the feet.
        #expect(!view.isCovered(byRectX: 88, y: 180, w: 25, h: 20, x: 100, y: 200))
    }
}
