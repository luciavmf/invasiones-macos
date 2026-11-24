//
//  Episode.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Episodio.cs + Episode.EstadoCargando.cs + Episode.EstadoJugando.cs
//  + Episode.EstadoMostrarIntroduccion.cs — active game session.
//

import Foundation
internal import CoreGraphics

/// The active battle session. Owns the map, both factions, the HUD, obstacles, and the current objective.
/// Manages the full battle lifecycle: LOADING → SHOW_INTRO → PLAYING → WON / LOST.
final class Episode {

    // MARK: - Enums
    /// The factions a unit can belong to.
    enum Faction { case enemy, argentine }

    /// The states the battle can be in.
    enum State: Int {
        case end = -1, loading, playing, showIntro, showObjectives, won, lost
    }

    // MARK: - Constants
    /// Number of frames to wait before showing the restart prompt after losing.
    enum Constants {
        static let countdownToRestart = 50
        static let objectivesBoxWidth = 600
        static let objectivesBoxHeight = 270
        static let objectivesBoxButtonY = 70
        static let objectiveShowStartCount = 50
        static let objectivesButtonY = 510
        static let objectivesBorder = 100
        static let pagesPerIntro = 3
        static let loadingY = 200
    }

    // MARK: - Declarations
    /// "Next" button used in the introduction/objectives screens.
    private var button: Button?
    /// "Accept" button used in the objectives popup.
    private var acceptButton: Button?
    /// All static obstacles loaded from the map (trees, buildings, rocks).
    private var obstacles: [Obstacle] = []
    /// The level definition (battles and objectives).
    private var currentLevel: Level?
    /// The index of the level being played.
    private var levelIndex: Int = 0
    /// The shared object table indexed by physical tile position.
    private var objectsToDraw = ObjectTable([[]])
    private var camera: Camera?
    /// The current objective the player must fulfill.
    private var objective: Objective?
    private var enemy: EnemyTeam?
    private var player: ArgentineTeam?
    private var map: Map?
    private var stateValue: State = .loading
    private var hud: Hud?
    /// General-purpose frame counter used by multiple states.
    private var count: Int = 0
    /// Whether to show the full objective popup (new objective acquired).
    private var showObjectivePopup: Bool = false
    /// Whether to show the small objective reminder overlay during gameplay.
    private var showObjectiveReminder: Bool = false
    private var objectiveShowCount: Int = 0
    /// The current intro/objective page being displayed.
    private var currentPage: Int = 0
    private var gameOverMenu: ConfirmationMenu
    // MARK: - Cheats
    private let cheatsEnabled = true

    // Cheats
    private var cheatWinIndex: Int = 0
    private var cheatLoseIndex: Int = 0
    private var cheatObjectiveIndex: Int = 0

    // MARK: - Properties
    var state: State { stateValue }

    // MARK: - Initializer
    init() {
        gameOverMenu = ConfirmationMenu(.playAgain, .no, .yes)
        gameOverMenu.setPosition(x: 0, y: 0, anchor: .center)
    }

    // MARK: - Public control

    /// Starts the battle by entering the loading state.
    func start() {
        setState(.loading)
    }


    /// Called when leaving the battle state (no-op).
    func exit() {}

    // MARK: - Update

    @discardableResult
    func update() -> Bool {
        switch stateValue {
        case .loading: updateLoadingState()
        case .showIntro: updateShowIntroState()
        case .showObjectives: updateShowObjectiveState()
        case .playing: updatePlayingState()
        case .won: updateWonState()
        case .lost: updateLostState()
        case .end: break
        }
        return false
    }

    // MARK: - Draw

    func draw(_ video: Video) {
        switch stateValue {
        case .loading: drawLoadingState(video)
        case .showObjectives: drawShowObjectiveState(video)
        case .playing: drawPlayingState(video)
        case .showIntro: drawShowIntroState(video)
        case .won: drawWonState(video)
        case .lost: drawLostState(video)
        case .end: break
        }
        video.color = GameColor.white
    }

    // MARK: - LOADING state

    private func updateLoadingState() {
        do {
            if try loadLevel(0) {
                updatePlayingState()
                setNewObjective()
                Sound.shared.stop(Res.SFX_SPLASH)
                Sound.shared.play(id: Res.SFX_BATALLA, loop: -1)
                setState(.showIntro)
            }
        } catch {
            Log.shared.error(error.localizedDescription)
        }
    }

    private func drawLoadingState(_ video: Video) {
        video.fillRect(.black)
        video.color = Theme.title
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.loading, 0, Constants.loadingY, .centerHorizontal)
    }

    private func loadSprites() {
        let sprs = ResourceManager.shared.sprites
        if Res.SPR_PATRICIO < sprs.count { try? sprs[Res.SPR_PATRICIO]?.load() }
        if Res.SPR_INGLES   < sprs.count { try? sprs[Res.SPR_INGLES]?.load()   }
    }

    private func loadPaintObjects() -> Bool {
        guard let map = map else { return false }

        objectsToDraw.tabla = Array(repeating: Array(repeating: nil, count: map.physicalMapWidth),
                                       count: map.physicalMapHeight)
        obstacles = []

        for i in 0..<map.height {
            for j in 0..<map.width {
                let tileId = Int(map.obstaclesLayer[i][j])
                guard tileId != 0 else { continue }
                guard let ts = map.getTileset(tileId) else { continue }

                let localId = tileId - Int(ts.firstGid)
                let obs = Obstacle(index: localId, i: i * 2, j: j * 2, tileset: ts)
                obstacles.append(obs)

                let fi = i * 2, fj = j * 2
                if fi < objectsToDraw.tabla.count, fj < objectsToDraw.tabla[fi].count {
                    objectsToDraw.tabla[fi][fj] = obs
                }
            }
        }
        return true
    }

    private func loadLevel(_ levelIndex: Int) throws -> Bool {
        if count == 0 {
            self.levelIndex = levelIndex
            hud = Hud()
            let hudHeight = hud?.height ?? 0
            let camera = Camera(x: 0, y: 0, height: Video.height - hudHeight)
            self.camera = camera
            map = Map(camera: camera)

        } else if count == 1 {
                        guard let map = map else {
                count += 1
                return false
            }
            try map.load(Res.MAP_NIVEL1 + levelIndex)

            MapObject.map = map
            MapObject.camera = camera

            let level = Level()
            level.load(levelIndex)
            currentLevel = level

        } else if count == 2 {
            loadSprites()

        } else if count == 3 {
            button = Button(label: .next, font: nil)
            acceptButton = Button(label: .accept, font: nil)
            ResourceManager.shared.loadUnitTypes()

        } else if count == 4 {
            if !loadPaintObjects() { return false }

        } else if count == 5 {
            guard let map = map, let camera = camera, let hud = hud else {
                count += 1
                return false
            }
            player = ArgentineTeam(map: map, camera: camera,
                                       objectsToDraw: objectsToDraw, hud: hud)
            enemy = EnemyTeam(map: map, camera: camera,
                                     objectsToDraw: objectsToDraw, hud: hud)

        } else if count == 6 {
            try player?.loadUnits(levelIndex)

        } else if count == 10 {
            try enemy?.loadUnits(levelIndex)
            count += 1
            return true
        }

        count += 1
        return false
    }

    // MARK: - SHOW INTRODUCTION state

    /// The intro text for the current battle and page, if there is one.
    private var currentIntroPage: StringID? {
        let battle = currentLevel?.currentBattleIndex ?? 0
        return StringID.introPages[safe: battle * Constants.pagesPerIntro + currentPage]
    }

    private func updateShowIntroState() {
        if count == 0 {
            button?.setPosition(x: 0, y: Constants.objectivesButtonY, anchor: .centerHorizontal)
        }
        count += 1
        if button?.update() != 0 {
            currentPage += 1
            if currentPage == Constants.pagesPerIntro - 1 {
                setState(.playing)
            }
        }
    }

    private func setNewObjective() {
        Log.shared.debug("Setting new objective.")
        showObjectivePopup = true
        let currentBattle = currentLevel?.currentBattleIndex ?? 0
        objective = currentLevel?.nextObjective()

        if (currentLevel?.currentBattleIndex ?? 0) != currentBattle {
            Log.shared.debug("Level completed.")
            setState(.showIntro)
        }
        showObjectivePopup = true
        objectiveShowCount = 0

        player?.setObjective(objective)

        if objective == nil {
            setState(.won)
        }
    }

    private func drawShowIntroState(_ video: Video) {
        drawPlayingState(video)

        video.color = Theme.objectivesText
        let hudHeight = hud?.height ?? 0
        video.fillRect(
            0, -(hudHeight >> 1),
            Video.width - (Constants.objectivesBorder << 1),
            Video.height  - (Constants.objectivesBorder << 1) - hudHeight,
            Theme.alpha,
            .center
        )

        if currentPage == 0 {
            video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
            video.fontColor = Theme.text
        } else {
            video.font = ResourceManager.shared.fonts[FontConstants.objectivesFont]
            video.fontColor = Theme.text
        }

        if let page = currentIntroPage {
            video.write(page, 0, -(hudHeight >> 1), .center)
        }
        button?.draw(video)
    }

    // MARK: - SHOW OBJECTIVES state

    private func updateShowObjectiveState() {
        if count == 0 {
            acceptButton?.setPosition(x: 0, y: Constants.objectivesBoxButtonY,
                                      anchor: .center)
        }
        count += 1
        if acceptButton?.update() != 0 {
            currentPage += 1
            if currentPage == Constants.pagesPerIntro {
                setState(.playing)
                showObjectivePopup = false
                showObjectiveReminder = true
            }
        }
    }

    private func drawShowObjectiveState(_ video: Video) {
        drawPlayingState(video)

        let hudHeight = hud?.height ?? 0
        video.color = Theme.objectivesText
        video.fillRect(
            0, -(hudHeight / 2),
            Constants.objectivesBoxWidth, Constants.objectivesBoxHeight,
            Theme.alpha,
            .center
        )

        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(
            .objectives, 0,
            -(hudHeight / 2) - Constants.objectivesBoxHeight / 2 + 50,
            .center
        )

        video.font = ResourceManager.shared.fonts[FontConstants.objectivesFont]
        video.fontColor = Theme.text
        if let page = currentIntroPage {
            video.write(page, 0, -(hudHeight >> 1) + 30, .center)
        }

        acceptButton?.draw(video)
    }

    // MARK: - PLAYING state

    private func updatePlayingState() {
        if showObjectivePopup { objectiveShowCount += 1 }

        if cheatsEnabled { checkCheats() }

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

        checkGameOver()

        hud?.update()
        updateOrders()

        obstacles.forEach { $0.update() }
    }

    private func checkGameOver() {
        if (player?.unitCount ?? 1) == 0 {
            setState(.lost)
        }
    }

    private func updateOrders() {
        if player?.completedObjective() == true {
            Log.shared.debug("Objective fulfilled.")
            setNewObjective()
        }
    }

    private func drawPlayingState(_ video: Video) {
        video.fillRect(GameColor.black)

        if let map = map { map.drawLayer(video: video, layer: map.layers.terrain) }

        dibujarObjetos(video)

        drawSemiTransparentLayer(video)

        hud?.draw(video)

        player?.drawOrientationArrow(video)

        if showObjectivePopup &&
           objectiveShowCount > Constants.objectiveShowStartCount {
            setState(.showObjectives)
        } else if showObjectiveReminder &&
                  objectiveShowCount > Constants.objectiveShowStartCount {
            let hudHeight = hud?.height ?? 0
            let cameraHeight = camera?.height ?? Video.height
            video.font = ResourceManager.shared.fonts[FontConstants.objectivesReminderFont]
            video.fontColor = Theme.title
            video.write(.objectives,
                       Layout.objectivesOffset << 1,
                       cameraHeight - (Layout.objectivesHeight + Layout.objectivesOffset * 2) - 10, [])
            if let reminder = StringID.objectiveReminders[safe: currentLevel?.completedObjectiveCount ?? 0] {
                video.write(reminder,
                           Layout.objectivesOffset << 1,
                           cameraHeight - (Layout.objectivesHeight + Layout.objectivesOffset * 2) + 5, [])
            }
            _ = hudHeight  // suppress warning
        }

        if Mouse.shared.isDragging() {
            video.color = GameColor.green
            let r = Mouse.shared.dragRect
            video.drawRect(Int(r.minX), Int(r.minY), Int(r.width), Int(r.height), [])
        }
    }

    private func drawSemiTransparentLayer(_ video: Video) {
        guard let map = map, let camera = camera, let player = player else { return }

        let oldClip = video.getClip()
        video.setClip(x: camera.startX, y: camera.startY, w: camera.width, h: camera.height)

        let rect = player.getPaintCoordinates()
        var startCol = rect.x
        var startRow = rect.y
        let endI = rect.w
        let endJ = rect.h

        var tileY = 0
        var toggle = true

        while tileY <= endJ {
            var tileX = 0
            var i = startCol, j = startRow
            while tileX <= endI && j >= 0 {
                if i >= 0 && i < map.physicalMapHeight && j < map.physicalMapWidth {
                    if map.visibleTilesLayer[i][j] == 0 {
                        map.drawSmallTile(video: video, i: i, j: j, semiTransparent: true)
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

        video.setClip(x: oldClip.x, y: oldClip.y, w: oldClip.w, h: oldClip.h)
    }

    private func dibujarObjetos(_ video: Video) {
        guard let map = map, let camera = camera, let player = player else { return }

        let oldClip = video.getClip()
        video.setClip(x: camera.startX, y: camera.startY, w: camera.width, h: camera.height)

        let rect = player.getPaintCoordinates()
        var startCol = rect.x
        var startRow = rect.y
        let endI = rect.w
        let endJ = rect.h

        var tileY = 0
        var toggle = true

        while tileY <= endJ {
            var tileX = 0
            var i = startCol, j = startRow
            while tileX <= endI && j >= 0 {
                if i >= 0 && i < map.physicalMapHeight && j < map.physicalMapWidth {
                    if let obj = objectsToDraw.tabla[i][j] {
                        if let uni = obj as? Unit  { uni.draw(video) }
                        if let obs = obj as? Obstacle { obs.draw(video) }
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

        // Fueguitos del jugador se dibujan encima (delegado a ArgentineFaction via Player)
        // player.Dibujar(g) — in the original it drew fire effects; delegated if needed

        video.setClip(x: oldClip.x, y: oldClip.y, w: oldClip.w, h: oldClip.h)
    }

    // MARK: - WON state

    private func updateWonState() {
        if button?.update() != 0 {
            setState(.end)
        }
    }

    private func drawWonState(_ video: Video) {
        drawPlayingState(video)
        button?.draw(video)
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.youWon, 0, 0, .center)
    }

    // MARK: - LOST state

    private func updateLostState() {
        count += 1
        guard count > Constants.countdownToRestart else { return }

        let result = gameOverMenu.update()
        if result == .left {
            setState(.end)
        }
        if result == .right {
            setState(.loading)
        }
    }

    private func drawLostState(_ video: Video) {
        drawPlayingState(video)
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.youLost, 0, -100, .center)
        if count > Constants.countdownToRestart {
            gameOverMenu.draw(video)
        }
    }

    // MARK: - Cheats

    private func checkCheats() {
        let keyboard = Keyboard.shared

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
            setNewObjective()
            cheatObjectiveIndex = 0
        } else if !keyboard.pressedKeys.isEmpty {
            if keyboard.isPressed(.u) { player?.selectNextUnit() }
            Log.shared.debug("Resetting all cheat indices.")
            cheatObjectiveIndex = 0
            cheatWinIndex = 0
            cheatLoseIndex = 0
        }
        Keyboard.shared.clearKeys()
    }

    // MARK: - Private

    private func setState(_ state: State) {
        count = 0
        stateValue = state
        currentPage = 0
        if state == .showObjectives { currentPage = 2 }
    }
}
