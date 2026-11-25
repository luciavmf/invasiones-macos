//
//  BattleFlow.swift
//  Invasiones
//
//  The states a battle goes through and when it switches between them, without drawing.
//  Port of the state handling in Episodio.cs and its partial files. The rules are
//  described in docs/specs/battle-flow.md.
//

/// What the battle flow needs from a level: its objectives, one at a time.
protocol ObjectiveSource: AnyObject {
    /// The battle being played. It moves on when a battle's objectives run out.
    var currentBattleIndex: Int { get }
    /// How many objectives have been completed (-1 before the first one is given).
    var completedObjectiveCount: Int { get }
    /// The next objective, or `nil` when the level has none left.
    func nextObjective() -> Objective?
}

extension Level: ObjectiveSource {}

/// The keyboard state the cheats read, so tests can use a fake.
protocol KeyboardDevice: AnyObject {
    var pressedKeys: [Int] { get }
    func isPressed(_ key: Keyboard.Key) -> Bool
    func clearKeys()
}

extension Keyboard: KeyboardDevice {}

/// The battle's state machine: loading → intro → playing ⇄ objectives → won or lost.
final class BattleFlow {

    /// The states a battle can be in.
    enum State {
        case end, loading, playing, showIntro, showObjectives, won, lost
    }

    enum Constants {
        /// Frames after losing before the play-again menu appears.
        static let countdownToRestart = 50
        /// Frames of play after a new objective before the objectives popup opens.
        static let objectiveShowStartCount = 50
        /// Text pages per battle: the intro shows the first two, the objectives popup the third.
        static let pagesPerIntro = 3
    }

    /// The level whose objectives are played. Set while loading.
    var level: (any ObjectiveSource)?
    /// Called with each new objective, and with `nil` when the level is won.
    var onNewObjective: ((Objective?) -> Void)?

    private(set) var state: State = .loading
    /// Frames spent in the current state. While loading, it's the loading step.
    private(set) var count = 0
    /// The page shown in the intro or the objectives popup.
    private(set) var page = 0
    /// The objective being played.
    private(set) var objective: Objective?

    /// Whether a new objective is waiting to be shown in the objectives popup.
    private(set) var showObjectivePopup = false
    /// Whether the objective reminder is shown in the corner while playing.
    private(set) var showObjectiveReminder = false
    /// Frames played since the current objective was given.
    private(set) var objectiveShowCount = 0

    private var cheatWinIndex = 0
    private var cheatLoseIndex = 0
    private var cheatObjectiveIndex = 0

    // MARK: - Loading

    /// Starts the battle by loading it.
    func start() {
        setState(.loading)
    }

    /// Moves on to the next loading step.
    func advanceLoading() {
        count += 1
    }

    /// Gives the first objective and shows the intro.
    func finishLoading() {
        advanceObjective()
        setState(.showIntro)
    }

    // MARK: - Intro and objectives

    /// The index of the text page shown, counted from the first battle's first page.
    var textPage: Int {
        (level?.currentBattleIndex ?? 0) * Constants.pagesPerIntro + page
    }

    /// A frame of the intro. Pressing "Next" turns the page; after the second page, the battle starts.
    func updateIntro(nextPressed: Bool) {
        count += 1
        guard nextPressed else { return }
        page += 1
        if page == Constants.pagesPerIntro - 1 {
            setState(.playing)
        }
    }

    /// A frame of the objectives popup. Accepting it goes back to playing, with the reminder shown.
    func updateObjectives(accepted: Bool) {
        count += 1
        guard accepted else { return }
        page += 1
        if page == Constants.pagesPerIntro {
            setState(.playing)
            showObjectivePopup = false
            showObjectiveReminder = true
        }
    }

    // MARK: - Playing

    /// Starts a frame of play: counts the frames since the objective was given.
    func beginPlayingFrame() {
        if showObjectivePopup { objectiveShowCount += 1 }
    }

    /// Loses the battle when the player has no units left.
    func checkGameOver(argentineUnitCount: Int) {
        if argentineUnitCount == 0 {
            setState(.lost)
        }
    }

    /// Gives the next objective once the player completes the current one.
    func objectiveCompleted() {
        Log.shared.debug("Objective fulfilled.")
        advanceObjective()
    }

    /// Whether the objectives popup is due: a new objective has been played for long enough.
    private var objectivesPopupIsDue: Bool {
        showObjectivePopup && objectiveShowCount > Constants.objectiveShowStartCount
    }

    /// Opens the objectives popup when it's due. The original checks this while drawing the
    /// battle, so it runs in every state that draws the battle behind its own screen.
    func showObjectivesIfDue() {
        if objectivesPopupIsDue {
            setState(.showObjectives)
        }
    }

    /// Whether the objective reminder is drawn in the corner of the battle.
    var showsReminder: Bool {
        !objectivesPopupIsDue && showObjectiveReminder
            && objectiveShowCount > Constants.objectiveShowStartCount
    }

    // MARK: - Won and lost

    /// The player pressed "Next" on the won screen: the battle ends.
    func confirmWon() {
        setState(.end)
    }

    /// A frame of the lost screen.
    func updateLost() {
        count += 1
    }

    /// Whether the lost screen shows the play-again menu.
    var showsPlayAgainMenu: Bool {
        count > Constants.countdownToRestart
    }

    /// The answer to "play again?": yes loads the battle again, no ends it.
    func answerPlayAgain(_ yes: Bool) {
        setState(yes ? .loading : .end)
    }

    // MARK: - Cheats

    /// Reads one frame of keys for the cheats, typed one letter at a time:
    /// G-A-N-X-W wins, P-E-R-X-W loses and O-B-J-X-W skips the objective.
    /// Any other key resets them; U also selects the next unit.
    /// - Returns: whether the next unit should be selected.
    @discardableResult
    func checkCheats(_ keyboard: any KeyboardDevice) -> Bool {
        var selectNextUnit = false

        if keyboard.isPressed(.g) && cheatWinIndex == 0 {
            cheatWinIndex += 1
        } else if keyboard.isPressed(.a) && cheatWinIndex == 1 {
            cheatWinIndex += 1
        } else if keyboard.isPressed(.n) && cheatWinIndex == 2 {
            cheatWinIndex += 1
        } else if keyboard.isPressed(.x) && cheatWinIndex == 3 {
            cheatWinIndex += 1
        } else if keyboard.isPressed(.w) && cheatWinIndex == 4 {
            setState(.won)
            cheatWinIndex = 0
        } else if keyboard.isPressed(.p) && cheatLoseIndex == 0 {
            cheatLoseIndex += 1
        } else if keyboard.isPressed(.e) && cheatLoseIndex == 1 {
            cheatLoseIndex += 1
        } else if keyboard.isPressed(.r) && cheatLoseIndex == 2 {
            cheatLoseIndex += 1
        } else if keyboard.isPressed(.x) && cheatLoseIndex == 3 {
            cheatLoseIndex += 1
        } else if keyboard.isPressed(.w) && cheatLoseIndex == 4 {
            setState(.lost)
            cheatLoseIndex = 0
        } else if keyboard.isPressed(.o) && cheatObjectiveIndex == 0 {
            cheatObjectiveIndex += 1
        } else if keyboard.isPressed(.b) && cheatObjectiveIndex == 1 {
            cheatObjectiveIndex += 1
        } else if keyboard.isPressed(.j) && cheatObjectiveIndex == 2 {
            cheatObjectiveIndex += 1
        } else if keyboard.isPressed(.x) && cheatObjectiveIndex == 3 {
            cheatObjectiveIndex += 1
        } else if keyboard.isPressed(.w) && cheatObjectiveIndex == 4 {
            // The original doesn't reset this cheat, so the next key only resets it.
            cheatObjectiveIndex += 1
            advanceObjective()
        } else if !keyboard.pressedKeys.isEmpty {
            selectNextUnit = keyboard.isPressed(.u)
            Log.shared.debug("Resetting all cheat indices.")
            cheatObjectiveIndex = 0
            cheatWinIndex = 0
            cheatLoseIndex = 0
        }
        keyboard.clearKeys()
        return selectNextUnit
    }

    // MARK: - Private

    /// Takes the level's next objective. Starting a new battle shows its intro; running out
    /// of objectives wins the level.
    private func advanceObjective() {
        Log.shared.debug("Setting new objective.")
        let battle = level?.currentBattleIndex ?? 0
        objective = level?.nextObjective()

        if (level?.currentBattleIndex ?? 0) != battle {
            Log.shared.debug("Level completed.")
            setState(.showIntro)
        }
        showObjectivePopup = true
        objectiveShowCount = 0

        onNewObjective?(objective)

        if objective == nil {
            setState(.won)
        }
    }

    private func setState(_ state: State) {
        count = 0
        self.state = state
        page = state == .showObjectives ? Constants.pagesPerIntro - 1 : 0
    }
}
