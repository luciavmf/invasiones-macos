//
//  Episode.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Episodio.cs + Episodio.EstadoCargando.cs + Episodio.EstadoJugando.cs
//  + Episodio.EstadoMostrarIntroduccion.cs — active game session.
//

import Foundation

/// The active battle session. Loads the map, both teams, the HUD and the obstacles, and
/// updates them while playing. `BattleFlow` decides which state the battle is in
/// (loading → intro → playing ⇄ objectives → won / lost), and each state's screen draws
/// it over the `BattleView`.
final class Episode {

    // MARK: - Enums
    /// The factions a unit can belong to.
    enum Faction { case enemy, argentine }

    /// The states the battle can be in.
    typealias State = BattleFlow.State

    // MARK: - Declarations
    /// All static obstacles loaded from the map (trees, buildings, rocks).
    private var obstacles: [Obstacle] = []
    /// The index of the level being played.
    private var levelIndex: Int = 0
    /// The shared object table indexed by physical tile position.
    private var objectsToDraw = ObjectTable([[]])
    private var camera: Camera?
    private var enemy: EnemyTeam?
    private var player: ArgentineTeam?
    private var map: Map?
    /// The map and camera, given to everything placed on the map.
    private var battlefield: Battlefield?
    private var hud: Hud?
    /// The battle's states and objectives.
    private let flow = BattleFlow()
    private let cheatsEnabled = true
    /// Where the battle's files, images, fonts, sprites and unit stats come from.
    private let resources: ResourceManager

    // MARK: - Screens
    private var battleView: BattleView?
    private var introScreen: IntroScreen?
    private var objectivesScreen: ObjectivesScreen?
    private var wonScreen: WonScreen?
    private var lostScreen: LostScreen?

    // MARK: - Properties
    var state: State { flow.state }

    // MARK: - Initializer
    init(resources: ResourceManager = .shared) {
        self.resources = resources
        flow.onNewObjective = { [weak self] objective in
            self?.player?.setObjective(objective)
        }
    }

    // MARK: - Public control

    /// Starts the battle by entering the loading state.
    func start() {
        flow.start()
    }

    /// Called when leaving the battle state (no-op).
    func exit() {}

    // MARK: - Update

    func update() {
        switch flow.state {
        case .loading:
            updateLoadingState()
        case .showIntro:
            if let introScreen { flow.updateIntro(nextPressed: introScreen.update()) }
        case .showObjectives:
            if let objectivesScreen { flow.updateObjectives(accepted: objectivesScreen.update()) }
        case .playing:
            updatePlayingState()
        case .won:
            if wonScreen?.update() == true { flow.confirmWon() }
        case .lost:
            flow.updateLost()
            if flow.showsPlayAgainMenu, let answer = lostScreen?.update() {
                flow.answerPlayAgain(answer)
            }
        case .end:
            break
        }
    }

    // MARK: - Draw

    func draw(_ video: Video) {
        switch flow.state {
        case .loading:
            LoadingScreen.draw(video, resources: resources)
        case .showIntro:
            drawBattle(video)
            introScreen?.draw(video, page: flow.page, text: currentTextPage)
        case .showObjectives:
            drawBattle(video)
            objectivesScreen?.draw(video, text: currentTextPage)
        case .playing:
            drawBattle(video)
        case .won:
            drawBattle(video)
            wonScreen?.draw(video)
        case .lost:
            drawBattle(video)
            lostScreen?.draw(video, showsMenu: flow.showsPlayAgainMenu)
        case .end:
            break
        }
        video.color = GameColor.white
    }

    /// The intro or objectives text for the current battle and page, if there is one.
    private var currentTextPage: StringID? {
        StringID.introPages[safe: flow.textPage]
    }

    /// Draws the battle behind the current screen.
    private func drawBattle(_ video: Video) {
        // The original opens the objectives popup while drawing the battle.
        flow.showObjectivesIfDue()
        let reminder: BattleView.Reminder = flow.showsReminder
            ? .shown(StringID.objectiveReminders[safe: flow.level?.completedObjectiveCount ?? 0])
            : .hidden
        battleView?.draw(video, reminder: reminder)
    }

    // MARK: - Loading

    private func updateLoadingState() {
        do {
            if try loadLevel(0) {
                updatePlayingState()
                flow.finishLoading()
                Sound.shared.stop(.splash)
                Sound.shared.play(id: .battle, loop: -1)
            }
        } catch {
            Log.shared.error(error.localizedDescription)
        }
    }

    private func loadSprites() {
        for sprite in resources.sprites.values {
            try? sprite.load()
        }
    }

    /// Places the map's obstacles in the object table.
    private func placeObstacles() throws {
        guard let map = map, let battlefield = battlefield else {
            throw GameError.invalidResource("Episode: the obstacles were loaded before the map.")
        }

        objectsToDraw.table = Array(repeating: Array(repeating: nil, count: map.physicalMapWidth),
                                       count: map.physicalMapHeight)
        obstacles = []

        for i in 0..<map.height {
            for j in 0..<map.width {
                let tileId = Int(map.obstaclesLayer[i][j])
                guard tileId != 0 else { continue }
                guard let ts = map.getTileset(tileId) else { continue }

                let localId = tileId - Int(ts.firstGid)
                let obs = Obstacle(index: localId, i: i * 2, j: j * 2, tileset: ts, battlefield: battlefield)
                obstacles.append(obs)

                let fi = i * 2, fj = j * 2
                if fi < objectsToDraw.table.count, fj < objectsToDraw.table[fi].count {
                    objectsToDraw.table[fi][fj] = obs
                }
            }
        }
    }

    /// Runs the loading step `flow.count` (one per frame, see docs/specs/battle-flow.md).
    /// - Returns: whether loading is finished.
    private func loadLevel(_ levelIndex: Int) throws -> Bool {
        if flow.count == 0 {
            self.levelIndex = levelIndex
            hud = Hud()
            let hudHeight = hud?.height ?? 0
            let camera = Camera(x: 0, y: 0, height: Video.height - hudHeight)
            self.camera = camera
            let map = Map(camera: camera, resources: resources)
            self.map = map
            battlefield = Battlefield(map: map, camera: camera)

        } else if flow.count == 1 {
            guard let map = map, let battlefield = battlefield else {
                flow.advanceLoading()
                return false
            }
            try map.load(level: levelIndex)

            let level = Level()
            level.load(levelIndex, battlefield: battlefield, resources: resources)
            flow.level = level

        } else if flow.count == 2 {
            loadSprites()

        } else if flow.count == 3 {
            let hudHeight = hud?.height ?? 0
            introScreen = IntroScreen(hudHeight: hudHeight, resources: resources)
            objectivesScreen = ObjectivesScreen(hudHeight: hudHeight, resources: resources)
            wonScreen = WonScreen(resources: resources)
            lostScreen = LostScreen(resources: resources)
            resources.loadUnitTypes()

        } else if flow.count == 4 {
            try placeObstacles()

        } else if flow.count == 5 {
            guard let map = map, let camera = camera, let hud = hud else {
                flow.advanceLoading()
                return false
            }
            player = ArgentineTeam(map: map, camera: camera, objectsToDraw: objectsToDraw, hud: hud,
                                   resources: resources)
            enemy = EnemyTeam(map: map, camera: camera, objectsToDraw: objectsToDraw, hud: hud,
                              resources: resources)
            if let player {
                battleView = BattleView(map: map, camera: camera, player: player,
                                        objectsToDraw: objectsToDraw, hud: hud, resources: resources)
            }

        } else if flow.count == 6 {
            try player?.loadUnits(levelIndex)

        } else if flow.count == 10 {
            try enemy?.loadUnits(levelIndex)
            flow.advanceLoading()
            return true
        }

        flow.advanceLoading()
        return false
    }

    // MARK: - Playing

    private func updatePlayingState() {
        flow.beginPlayingFrame()

        if cheatsEnabled, flow.checkCheats(Keyboard.shared) {
            player?.selectNextUnit()
        }

        map?.update()

        // Reset visibility layer
        if let map = map {
            map.visibleTilesLayer = Array(repeating: Array(repeating: 0, count: map.physicalMapWidth),
                                           count: map.physicalMapHeight)
        }

        player?.update()
        enemy?.update()

        hud?.argentineCount = player?.unitCount ?? 0
        hud?.enemyCount = enemy?.unitCount ?? 0

        flow.checkGameOver(argentineUnitCount: player?.unitCount ?? 1)

        hud?.update()
        if player?.completedObjective() == true {
            flow.objectiveCompleted()
        }

        obstacles.forEach { $0.update() }
    }
}
