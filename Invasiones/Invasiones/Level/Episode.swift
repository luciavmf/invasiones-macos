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

/// The active battle session. Owns the map, both factions, the HUD and the obstacles, and
/// draws the battle. Its states and transitions (loading → intro → playing ⇄ objectives →
/// won / lost) are in `BattleFlow`.
final class Episode {

    // MARK: - Enums
    /// The factions a unit can belong to.
    enum Faction { case enemy, argentine }

    /// The states the battle can be in.
    typealias State = BattleFlow.State

    // MARK: - Constants
    enum Constants {
        static let objectivesBoxWidth = 600
        static let objectivesBoxHeight = 270
        static let objectivesBoxButtonY = 70
        static let objectivesButtonY = 510
        static let objectivesBorder = 100
        static let loadingY = 200
    }

    // MARK: - Declarations
    /// "Next" button used in the introduction/objectives screens.
    private var button: Button?
    /// "Accept" button used in the objectives popup.
    private var acceptButton: Button?
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
    private var gameOverMenu: ConfirmationMenu
    /// The battle's states and objectives.
    private let flow = BattleFlow()
    private let cheatsEnabled = true

    // MARK: - Properties
    var state: State { flow.state }

    // MARK: - Initializer
    init() {
        gameOverMenu = ConfirmationMenu(.playAgain, .no, .yes)
        gameOverMenu.setPosition(x: 0, y: 0, anchor: .center)
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

    @discardableResult
    func update() -> Bool {
        switch flow.state {
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
        switch flow.state {
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
                flow.finishLoading()
                Sound.shared.stop(.splash)
                Sound.shared.play(id: .battle, loop: -1)
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
        for sprite in ResourceManager.shared.sprites.values {
            try? sprite.load()
        }
    }

    private func loadPaintObjects() -> Bool {
        guard let map = map, let battlefield = battlefield else { return false }

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
        return true
    }

    private func loadLevel(_ levelIndex: Int) throws -> Bool {
        if flow.count == 0 {
            self.levelIndex = levelIndex
            hud = Hud()
            let hudHeight = hud?.height ?? 0
            let camera = Camera(x: 0, y: 0, height: Video.height - hudHeight)
            self.camera = camera
            let map = Map(camera: camera)
            self.map = map
            battlefield = Battlefield(map: map, camera: camera)

        } else if flow.count == 1 {
            guard let map = map, let battlefield = battlefield else {
                flow.advanceLoading()
                return false
            }
            try map.load(level: levelIndex)

            let level = Level()
            level.load(levelIndex, battlefield: battlefield)
            flow.level = level

        } else if flow.count == 2 {
            loadSprites()

        } else if flow.count == 3 {
            button = Button(label: .next, font: nil)
            acceptButton = Button(label: .accept, font: nil)
            ResourceManager.shared.loadUnitTypes()

        } else if flow.count == 4 {
            if !loadPaintObjects() { return false }

        } else if flow.count == 5 {
            guard let map = map, let camera = camera, let hud = hud else {
                flow.advanceLoading()
                return false
            }
            player = ArgentineTeam(map: map, camera: camera,
                                       objectsToDraw: objectsToDraw, hud: hud)
            enemy = EnemyTeam(map: map, camera: camera,
                                     objectsToDraw: objectsToDraw, hud: hud)

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

    // MARK: - SHOW INTRODUCTION state

    /// The intro or objectives text for the current battle and page, if there is one.
    private var currentIntroPage: StringID? {
        StringID.introPages[safe: flow.textPage]
    }

    private func updateShowIntroState() {
        if flow.count == 0 {
            button?.setPosition(x: 0, y: Constants.objectivesButtonY, anchor: .centerHorizontal)
        }
        flow.updateIntro(nextPressed: button?.update() != 0)
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

        if flow.page == 0 {
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
        if flow.count == 0 {
            acceptButton?.setPosition(x: 0, y: Constants.objectivesBoxButtonY,
                                      anchor: .center)
        }
        flow.updateObjectives(accepted: acceptButton?.update() != 0)
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

    private func drawPlayingState(_ video: Video) {
        video.fillRect(GameColor.black)

        if let map = map { map.drawLayer(video: video, layer: map.layers.terrain) }

        drawObjects(video)

        drawSemiTransparentLayer(video)

        hud?.draw(video)

        player?.drawOrientationArrow(video)

        // The original opens the objectives popup while drawing the battle.
        flow.showObjectivesIfDue()
        if flow.showsReminder {
            let cameraHeight = camera?.height ?? Video.height
            video.font = ResourceManager.shared.fonts[FontConstants.objectivesReminderFont]
            video.fontColor = Theme.title
            video.write(.objectives,
                       Layout.objectivesOffset << 1,
                       cameraHeight - (Layout.objectivesHeight + Layout.objectivesOffset * 2) - 10, [])
            if let reminder = StringID.objectiveReminders[safe: flow.level?.completedObjectiveCount ?? 0] {
                video.write(reminder,
                           Layout.objectivesOffset << 1,
                           cameraHeight - (Layout.objectivesHeight + Layout.objectivesOffset * 2) + 5, [])
            }
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

    private func drawObjects(_ video: Video) {
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
                    if let obj = objectsToDraw.table[i][j] {
                        if let unit = obj as? Unit  { unit.draw(video) }
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

        video.setClip(x: oldClip.x, y: oldClip.y, w: oldClip.w, h: oldClip.h)
    }

    // MARK: - WON state

    private func updateWonState() {
        if button?.update() != 0 {
            flow.confirmWon()
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
        flow.updateLost()
        guard flow.showsPlayAgainMenu else { return }

        let result = gameOverMenu.update()
        if result == .left {
            flow.answerPlayAgain(false)
        }
        if result == .right {
            flow.answerPlayAgain(true)
        }
    }

    private func drawLostState(_ video: Video) {
        drawPlayingState(video)
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.youLost, 0, -100, .center)
        if flow.showsPlayAgainMenu {
            gameOverMenu.draw(video)
        }
    }
}
