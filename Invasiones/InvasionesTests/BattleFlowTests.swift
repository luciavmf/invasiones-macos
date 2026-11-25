//
//  BattleFlowTests.swift
//  InvasionesTests
//
//  The battle's states and transitions, checked against the C# original (Episodio.cs).
//  The rules are described in docs/specs/battle-flow.md.
//

import Testing
@testable import Invasiones

@MainActor
struct BattleFlowTests {

    private let flow = BattleFlow()
    private let keyboard = FakeKeyboard()

    /// A flow whose level has the given objectives per battle, loaded and on the intro.
    private func loadedFlow(objectivesPerBattle: [Int] = [2]) -> BattleFlow {
        flow.level = FakeLevel(objectivesPerBattle: objectivesPerBattle)
        flow.start()
        flow.finishLoading()
        return flow
    }

    /// Turns the two intro pages, which starts the battle.
    private func skipIntro() {
        flow.updateIntro(nextPressed: true)
        flow.updateIntro(nextPressed: true)
    }

    /// Plays frames the way `Episode` does: the frame's update, then the check made while drawing.
    private func play(frames: Int) {
        for _ in 0..<frames {
            flow.beginPlayingFrame()
            flow.showObjectivesIfDue()
        }
    }

    private func type(_ keys: Keyboard.Key...) {
        for key in keys {
            keyboard.press(key)
            flow.checkCheats(keyboard)
        }
    }

    // MARK: - Loading and intro

    @Test func aBattleStartsLoading() {
        flow.start()

        #expect(flow.state == .loading)
    }

    @Test func loadingStepsAreCounted() {
        flow.start()

        flow.advanceLoading()
        flow.advanceLoading()

        #expect(flow.count == 2)
    }

    @Test func finishingLoadingGivesTheFirstObjectiveAndShowsTheIntro() {
        var given: [Objective?] = []
        flow.onNewObjective = { given.append($0) }

        _ = loadedFlow()

        #expect(flow.state == .showIntro)
        #expect(flow.page == 0)
        #expect(flow.objective != nil)
        #expect(given.count == 1)
    }

    @Test func theIntroShowsTwoPagesThenStartsTheBattle() {
        _ = loadedFlow()

        flow.updateIntro(nextPressed: false)
        #expect(flow.page == 0)

        flow.updateIntro(nextPressed: true)
        #expect(flow.state == .showIntro)
        #expect(flow.page == 1)

        flow.updateIntro(nextPressed: true)
        #expect(flow.state == .playing)
    }

    @Test func theTextPageCountsThreePagesPerBattle() {
        _ = loadedFlow(objectivesPerBattle: [1, 1])
        skipIntro()

        flow.objectiveCompleted()

        #expect(flow.state == .showIntro)
        #expect(flow.textPage == 3)
    }

    // MARK: - Objectives popup and reminder

    @Test func theObjectivesPopupOpensAfterFiftyOneFramesOfPlay() {
        _ = loadedFlow()
        skipIntro()

        play(frames: BattleFlow.Constants.objectiveShowStartCount)
        #expect(flow.state == .playing)

        play(frames: 1)
        #expect(flow.state == .showObjectives)
        #expect(flow.page == 2)
    }

    @Test func acceptingTheObjectivesGoesBackToPlayingWithTheReminder() {
        _ = loadedFlow()
        skipIntro()
        play(frames: 51)

        flow.updateObjectives(accepted: true)

        #expect(flow.state == .playing)
        #expect(flow.showsReminder)
        play(frames: 1)
        #expect(flow.state == .playing)
    }

    @Test func aNewObjectiveHidesTheReminderAndOpensThePopupAgain() {
        _ = loadedFlow(objectivesPerBattle: [2])
        skipIntro()
        play(frames: 51)
        flow.updateObjectives(accepted: true)

        flow.objectiveCompleted()
        #expect(flow.state == .playing)
        #expect(!flow.showsReminder)

        play(frames: 51)
        #expect(flow.state == .showObjectives)
    }

    // MARK: - Objectives, winning and losing

    @Test func finishingABattleShowsTheNextBattlesIntro() {
        _ = loadedFlow(objectivesPerBattle: [1, 1])
        skipIntro()

        flow.objectiveCompleted()

        #expect(flow.state == .showIntro)
        #expect(flow.page == 0)
    }

    @Test func runningOutOfObjectivesWinsTheBattle() {
        var given: [Objective?] = []
        flow.onNewObjective = { given.append($0) }
        _ = loadedFlow(objectivesPerBattle: [1])
        skipIntro()

        flow.objectiveCompleted()

        #expect(flow.state == .won)
        #expect(given.count == 2)
        #expect(given.last! == nil)
    }

    @Test func confirmingTheWinEndsTheBattle() {
        _ = loadedFlow(objectivesPerBattle: [1])
        skipIntro()
        flow.objectiveCompleted()

        flow.confirmWon()

        #expect(flow.state == .end)
    }

    @Test func losingEveryUnitLosesTheBattle() {
        _ = loadedFlow()
        skipIntro()

        flow.checkGameOver(argentineUnitCount: 1)
        #expect(flow.state == .playing)

        flow.checkGameOver(argentineUnitCount: 0)
        #expect(flow.state == .lost)
    }

    @Test func thePlayAgainMenuAppearsAfterFiftyOneFrames() {
        _ = loadedFlow()
        flow.checkGameOver(argentineUnitCount: 0)

        for _ in 0..<BattleFlow.Constants.countdownToRestart { flow.updateLost() }
        #expect(!flow.showsPlayAgainMenu)

        flow.updateLost()
        #expect(flow.showsPlayAgainMenu)
    }

    @Test(arguments: [(true, BattleFlow.State.loading), (false, .end)])
    func answeringPlayAgain(yes: Bool, next: BattleFlow.State) {
        _ = loadedFlow()
        flow.checkGameOver(argentineUnitCount: 0)

        flow.answerPlayAgain(yes)

        #expect(flow.state == next)
    }

    // MARK: - Cheats

    @Test func typingGANXWWins() {
        _ = loadedFlow()
        skipIntro()

        type(.g, .a, .n, .x)
        #expect(flow.state == .playing)
        type(.w)

        #expect(flow.state == .won)
    }

    @Test func typingPERXWLoses() {
        _ = loadedFlow()
        skipIntro()

        type(.p, .e, .r, .x, .w)

        #expect(flow.state == .lost)
    }

    @Test func typingOBJXWSkipsTheObjective() {
        var given = 0
        flow.onNewObjective = { _ in given += 1 }
        _ = loadedFlow(objectivesPerBattle: [3])
        skipIntro()

        type(.o, .b, .j, .x, .w)

        #expect(given == 2)
    }

    @Test func anotherKeyResetsTheCheats() {
        _ = loadedFlow()
        skipIntro()

        type(.g, .a, .q, .n, .x, .w)

        #expect(flow.state == .playing)
    }

    @Test func afterOBJXWTheNextKeyOnlyResetsTheCheat() {
        var given = 0
        flow.onNewObjective = { _ in given += 1 }
        _ = loadedFlow(objectivesPerBattle: [5])
        skipIntro()
        type(.o, .b, .j, .x, .w)

        // As in the original, the first O after the cheat resets it instead of starting it again.
        type(.o, .b, .j, .x, .w)
        #expect(given == 2)

        type(.o, .b, .j, .x, .w)
        #expect(given == 3)
    }

    @Test func uSelectsTheNextUnit() {
        keyboard.press(.u)

        #expect(flow.checkCheats(keyboard))
        #expect(keyboard.pressedKeys.isEmpty)
    }
}
