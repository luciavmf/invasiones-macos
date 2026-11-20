//
//  CreditsState.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 08.04.26.
//
//  Credits screen — shows programming and level design credits.
//

import Foundation

final class CreditsState: State {

    let stateMachine: StateMachine
    private var background: Surface?
    private var button: Button?

    init(_ sm: StateMachine) {
        stateMachine = sm
    }

    func start() {
        background = ResourceManager.shared.getImage(Res.IMG_FONDO)
        button = Button(label: Res.STR_BOTON_MENU, font: nil)
        let bw = button?.frame.width  ?? 0
        let bh = button?.frame.height ?? 0
        button?.setPosition(
            x: Video.width  - bw - Button.Constants.screenEdgeOffset,
            y: Video.height - bh - Button.Constants.screenEdgeOffset,
            anchor: 0)
    }

    func update() {
        if button?.update() != 0 {
            stateMachine.setNextState(.mainMenu)
        }
    }

    func draw(_ video: Video) {
        video.draw(background, 0, 0, 0)

        // Title
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(Res.STR_MENU_CREDITOS, 0, Layout.titleYPosition, Surface.centerHorizontal)

        // Programming
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(Res.STR_CREDITOS_PROGRAMACION, 0, 260, Surface.centerHorizontal)

        video.font = ResourceManager.shared.fonts[FontConstants.buttonFont]
        video.fontColor = Theme.text
        video.write(Res.STR_CREDITOS_PROGRAMADOR_1, 0, 310, Surface.centerHorizontal)

        // Level design
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(Res.STR_CREDITOS_DISENO_DE_NIVEL, 0, 400, Surface.centerHorizontal)

        video.font = ResourceManager.shared.fonts[FontConstants.buttonFont]
        video.fontColor = Theme.text
        video.write(Res.STR_CREDITOS_DISENADOR_DE_NIVEL_1, 0, 450, Surface.centerHorizontal)

        button?.draw(video)
    }

    func exit() {}
}
