//
//  ExitState.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of EstadoSalir.cs — exit confirmation dialog.
//

import Foundation

final class ExitState: State {

    let stateMachine: StateMachine
    private var background: Surface?

    init(_ sm: StateMachine) {
        stateMachine = sm
    }

    private var confirmMenu: ConfirmationMenu?

    func start() {
        background = ResourceManager.shared.getImage(Res.IMG_SPLASH)
        confirmMenu = ConfirmationMenu(Res.STR_CONFIRMACION_SALIR, Res.STR_NO, Res.STR_SI)
        confirmMenu?.setPosition(x: 0, y: 0, anchor: .center)
    }

    func update() {
        guard let result = confirmMenu?.update() else { return }
        if result == .right {
            stateMachine.setState(.end)
        }
        if result == .left {
            stateMachine.setNextState(.mainMenu)
        }
    }

    func draw(_ video: Video) {
        video.draw(background, 0, 0, [])
        confirmMenu?.draw(video)
    }

    func exit() {
        confirmMenu = nil
    }
}
