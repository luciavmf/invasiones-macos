//
//  UnitCombatTests.swift
//  InvasionesTests
//
//  Attacking, dying, healing and patrolling, checked against the C# original (Unidad.cs).
//  Where the port still differs, the test describes the original and is marked as a known issue.
//  The rules are described in docs/specs/combat.md.
//

import Testing
@testable import Invasiones

@MainActor
struct UnitCombatTests {

    /// An open field, 40×40 physical tiles.
    private let grid = TestGrid(Array(repeating: String(repeating: ".", count: 40), count: 40))
    private let pathFinder = PathFinder()
    private let sound = FakeSound()

    init() {
        pathFinder.load(grid: grid)
    }

    private func makeUnit(at j: Int, row i: Int = 20, faction: Episode.Faction = .argentine) -> GameUnit {
        let unit = GameUnit(battlefield: Battlefield(map: grid, camera: Camera(x: 0, y: 0, height: 600)),
                            pathFinder: pathFinder, sound: sound)
        unit.faction = faction
        unit.setTilePosition(i: i, j: j)
        return unit
    }

    private func update(_ units: GameUnit..., times: Int) {
        for _ in 0..<times { units.forEach { $0.update() } }
    }

    // MARK: - Attacking

    @Test func attackingAnEnemyInRangeStartsShooting() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 3, faction: .enemy)

        attacker.attack(enemy: enemy)
        attacker.update()

        #expect(attacker.currentState == .attacking)
    }

    @Test func anIdleTargetInRangeFightsBack() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 3, faction: .enemy)

        attacker.attack(enemy: enemy)
        attacker.update()

        #expect(enemy.currentState == .attacking)
    }

    @Test func aBusyTargetDoesNotFightBack() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 3, faction: .enemy)
        enemy.move(x: 20, y: 30)

        attacker.attack(enemy: enemy)
        attacker.update()

        #expect(enemy.currentState == .moving)
    }

    @Test func eachShotDealsTheAttackPointsOncePerInterval() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 3, faction: .enemy)
        attacker.attack(enemy: enemy)
        attacker.update()

        // Only the attacker is updated, so only it shoots.
        // The original fires on the frame after the interval, the port on its last frame.
        update(attacker, times: attacker.attackInterval)
        #expect(enemy.health >= enemy.resistancePoints - attacker.attackPoints)

        update(attacker, times: attacker.attackInterval + 2)
        #expect(enemy.health == enemy.resistancePoints - 2 * attacker.attackPoints)
        #expect(sound.played.filter { $0 == .patricioShot }.count == 2)
    }

    @Test func killingTheEnemyEndsTheAttack() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 3, faction: .enemy)
        enemy.takeDamage(enemy.resistancePoints - 1)
        attacker.attack(enemy: enemy)
        attacker.update()

        update(attacker, times: attacker.attackInterval + 2)

        #expect(enemy.isDead())
        #expect(attacker.currentState == .idle)
    }

    @Test func attackingADeadEnemyDoesNothing() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 3, faction: .enemy)
        enemy.takeDamage(enemy.resistancePoints)

        attacker.attack(enemy: enemy)
        attacker.update()

        #expect(attacker.currentState == .idle)
    }

    // MARK: - Pursuing

    @Test func anEnemyOutOfRangeIsChased() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 12, faction: .enemy)

        attacker.attack(enemy: enemy)
        attacker.update()

        withKnownIssue("The port turns the chase into a move to the enemy's tile, then goes idle") {
            #expect(attacker.currentState == .pursuingUnit)
        }
        #expect(attacker.pathToFollow != nil)
    }

    @Test func aChaseEndsInAnAttackOnceInRange() {
        let attacker = makeUnit(at: 0)
        let enemy = makeUnit(at: 12, faction: .enemy)
        attacker.attack(enemy: enemy)

        for _ in 0..<500 where attacker.currentState != .attacking {
            attacker.update()
        }

        withKnownIssue("The port turns the chase into a move to the enemy's tile, then goes idle") {
            #expect(attacker.currentState == .attacking)
        }
    }

    // MARK: - Dying

    @Test func aUnitWithNoHealthLeftDies() {
        let unit = makeUnit(at: 0)

        unit.takeDamage(unit.resistancePoints)

        #expect(unit.health == 0)
        #expect(unit.currentState == .dying)
        #expect(unit.isDead())
        #expect(sound.played == [.patricioDeath])
    }

    @Test func aDyingUnitIsDeadAfterTheDeathFrames() {
        let unit = makeUnit(at: 0)
        unit.takeDamage(unit.resistancePoints)

        update(unit, times: GameUnit.Constants.deathFrameCount - 1)
        #expect(unit.currentState == .dying)

        update(unit, times: 2)
        #expect(unit.currentState == .dead)
    }

    // MARK: - Healing

    @Test func healingRecoversHealthUntilFull() {
        let unit = makeUnit(at: 0)
        unit.takeDamage(50)
        unit.recoverHealth()

        update(unit, times: 200)

        #expect(unit.health == unit.resistancePoints)
        #expect(unit.currentState == .idle)
    }

    @Test func healingRecoversEveryHalfTheTicksBetweenRecoveries() {
        let unit = makeUnit(at: 0)
        unit.takeDamage(50)
        unit.recoverHealth()

        // The original counts each frame twice, so 50 ticks take 26 frames.
        update(unit, times: 26)

        withKnownIssue("The port waits the full 50 frames between recoveries") {
            #expect(unit.health == 70)
        }
    }

    // MARK: - Patrolling

    @Test func patrolsHeadEightToFifteenTilesFromTheStart() throws {
        let unit = makeUnit(at: 20)

        unit.patrol()

        #expect(unit.currentState == .patrolling)
        let destination = try #require(unit.pathToFollow?.first)
        #expect((8...15).contains(abs(destination.i - 20)))
        #expect((8...15).contains(abs(destination.j - 20)))
    }
}
