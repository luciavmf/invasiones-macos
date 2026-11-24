//
//  HelpState.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of HelpState.cs — help/tutorial screens with animations.
//

import Foundation

final class HelpState: State {

    let stateMachine: StateMachine
    private var background: Surface?
    private var button: Button?

    init(_ sm: StateMachine) {
        stateMachine = sm
    }

    // MARK: - Sub-states
    private enum Substate: Int {
        case select = 0, move, attack, objective, scroll, hud, heal, tips, win
        static let total = 9
    }

    private enum Constants {
        static let helpTextY = 200
        static let helpItemY = 150
    }

    // MARK: - Declarations
    private var substate: Substate = .select
    private var backButton: Button?
    private var nextButton: Button?
    private var currentScreenshot: Animation?

    // MARK: - Methods

    func start() {
        background = ResourceManager.shared.getImage(Res.IMG_FONDO)

        let fnt = ResourceManager.shared.fonts[.sans18]

        button = Button(label: Res.STR_BOTON_MENU, font: fnt)
        let bw = button?.frame.width  ?? 0
        let bh = button?.frame.height ?? 0
        button?.setPosition(
            x: Video.width  - bw - Button.Constants.screenEdgeOffset,
            y: Video.height - bh - Button.Constants.screenEdgeOffset,
            anchor: []
        )

        nextButton = Button(label: Res.STR_SIGUIENTE, font: fnt)
        let nw = nextButton?.frame.width  ?? 0
        let nh = nextButton?.frame.height ?? 0
        nextButton?.setPosition(
            x: Video.width  - nw - Button.Constants.screenEdgeOffset,
            y: Video.height - nh - Button.Constants.screenEdgeOffset,
            anchor: []
        )

        backButton = Button(label: Res.STR_ATRAS, font: fnt)
        backButton?.setPosition(
            x: Video.width  - nw * 2 - Button.Constants.screenEdgeOffset,
            y: Video.height - nh     - Button.Constants.screenEdgeOffset,
            anchor: []
        )

        substate = .select
        loadScreenshot(substate)
    }

    func update() {
        if button?.update() != 0 {
            let next = substate.rawValue + 1
            if next > Substate.win.rawValue {
                stateMachine.setNextState(.mainMenu)
            } else if let next = Substate(rawValue: next) {
                substate = next
                loadScreenshot(next)
            }
        }

        if backButton?.update() != 0, substate != .select {
            let prev = substate.rawValue - 1
            if let prev = Substate(rawValue: prev) {
                substate = prev
                loadScreenshot(prev)
            }
        }

        currentScreenshot?.update()
    }

    func draw(_ video: Video) {
        video.draw(background, 0, 0, [])

        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(Res.STR_MENU_AYUDA, 0, Layout.titleYPosition, .centerHorizontal)

        if substate.rawValue < Substate.total {
            video.font = ResourceManager.shared.fonts[FontConstants.helpTitleFont]
            video.fontColor = Theme.text
            video.write(Res.STR_MENU_AYUDA_TEXTO_SELECCIONAR_01 + substate.rawValue * 2,
                       0, Constants.helpItemY, .centerHorizontal)

            video.font = ResourceManager.shared.fonts[FontConstants.helpFont]
            video.fontColor = Theme.text
            video.write(Res.STR_MENU_AYUDA_TEXTO_SELECCIONAR_02 + substate.rawValue * 2,
                       0, Constants.helpTextY, .centerHorizontal)
        }

        currentScreenshot?.draw(video: video, x: 0, y: 150, anchor: .center)

        if substate != .select { backButton?.draw(video) }
        if substate != .win {
            nextButton?.draw(video)
        } else {
            button?.draw(video)
        }
    }

    func exit() {}

    // MARK: - Private

    private func loadScreenshot(_ sub: Substate) {
        let animIdx = Res.ANIM_AYUDA_SELECCION + sub.rawValue
        let anims = ResourceManager.shared.animations
        guard animIdx < anims.count, let anim = anims[animIdx] else {
            currentScreenshot = nil
            return
        }
        try? anim.load()
        anim.play()
        anim.loop = true
        currentScreenshot = anim
    }
}
