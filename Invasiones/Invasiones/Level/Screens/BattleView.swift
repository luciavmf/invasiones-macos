//
//  BattleView.swift
//  Invasiones
//
//  Draws the battle itself, behind every battle screen. Port of the drawing in
//  Episodio.EstadoJugando.cs.
//

internal import CoreGraphics

/// Draws the battle: the terrain, the units and obstacles, the fog of war, the HUD, the
/// player's markers, the objective reminder and the drag rectangle.
final class BattleView {

    /// What the objective reminder in the corner shows.
    enum Reminder {
        case hidden
        /// The "Objectives" title and, when there is one, the current objective's text.
        case shown(StringID?)
    }

    private let map: Map
    private let camera: Camera
    private let player: ArgentineTeam
    private let objectsToDraw: ObjectTable
    private let hud: Hud
    private let pointer: any PointerDevice

    init(map: Map, camera: Camera, player: ArgentineTeam, objectsToDraw: ObjectTable, hud: Hud,
         pointer: any PointerDevice = Mouse.shared) {
        self.map = map
        self.camera = camera
        self.player = player
        self.objectsToDraw = objectsToDraw
        self.hud = hud
        self.pointer = pointer
    }

    func draw(_ video: Video, reminder: Reminder) {
        video.fillRect(GameColor.black)

        map.drawLayer(video: video, layer: map.layers.terrain)

        drawObjects(video)

        drawFog(video)

        hud.draw(video)

        player.drawOrientationArrow(video)

        if case let .shown(text) = reminder {
            drawReminder(video, text: text)
        }

        if pointer.isDragging() {
            video.color = GameColor.green
            let r = pointer.dragRect
            video.drawRect(Int(r.minX), Int(r.minY), Int(r.width), Int(r.height), [])
        }
    }

    // MARK: - Private

    private func drawReminder(_ video: Video, text: StringID?) {
        let y = camera.height - (Layout.objectivesHeight + Layout.objectivesOffset * 2)
        video.font = ResourceManager.shared.fonts[FontConstants.objectivesReminderFont]
        video.fontColor = Theme.title
        video.write(.objectives, Layout.objectivesOffset << 1, y - 10, [])
        if let text {
            video.write(text, Layout.objectivesOffset << 1, y + 5, [])
        }
    }

    /// Draws the semi-transparent tiles over the parts of the map no unit sees.
    private func drawFog(_ video: Video) {
        forEachVisibleTile(video) { i, j in
            if map.visibleTilesLayer[i][j] == 0 {
                map.drawSmallTile(video: video, i: i, j: j, semiTransparent: true)
            }
        }
    }

    /// Draws the units and obstacles, back to front.
    private func drawObjects(_ video: Video) {
        forEachVisibleTile(video) { i, j in
            if let unit = objectsToDraw.table[i][j] as? Unit { unit.draw(video) }
            if let obstacle = objectsToDraw.table[i][j] as? Obstacle { obstacle.draw(video) }
        }
    }

    /// Calls `body` for every physical tile in the camera's view, row by row from the back,
    /// with drawing clipped to the camera.
    private func forEachVisibleTile(_ video: Video, _ body: (_ i: Int, _ j: Int) -> Void) {
        let oldClip = video.getClip()
        video.setClip(x: camera.startX, y: camera.startY, w: camera.width, h: camera.height)

        let rect = player.getPaintCoordinates()
        var startCol = rect.x
        var startRow = rect.y
        var toggle = true

        var tileY = 0
        while tileY <= rect.h {
            tileY += 1
            var i = startCol, j = startRow
            var tileX = 0
            while tileX <= rect.w && j >= 0 {
                if i >= 0 && i < map.physicalMapHeight && j < map.physicalMapWidth {
                    body(i, j)
                }
                tileX += 1
                i += 1
                j -= 1
            }
            if toggle {
                startCol += 1
            } else {
                startRow += 1
            }
            toggle.toggle()
        }

        video.setClip(x: oldClip.x, y: oldClip.y, w: oldClip.w, h: oldClip.h)
    }
}
