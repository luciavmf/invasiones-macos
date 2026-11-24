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
        background = ResourceManager.shared.getImage(.background)
        button = Button(label: .buttonBack, font: nil)
        let bw = button?.frame.width  ?? 0
        let bh = button?.frame.height ?? 0
        button?.setPosition(
            x: Video.width  - bw - Button.Constants.screenEdgeOffset,
            y: Video.height - bh - Button.Constants.screenEdgeOffset,
            anchor: [])
    }

    func update() {
        if button?.update() != 0 {
            stateMachine.setNextState(.mainMenu)
        }
    }

    func draw(_ video: Video) {
        video.draw(background, 0, 0, [])

        // Title
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(.menuCredits, 0, Layout.titleYPosition, .centerHorizontal)

        // Programming
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(.creditsProgramming, 0, 260, .centerHorizontal)

        video.font = ResourceManager.shared.fonts[FontConstants.buttonFont]
        video.fontColor = Theme.text
        video.write(.creditsProgrammer1, 0, 310, .centerHorizontal)

        // Level design
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(.creditsLevelDesign, 0, 400, .centerHorizontal)

        video.font = ResourceManager.shared.fonts[FontConstants.buttonFont]
        video.fontColor = Theme.text
        video.write(.creditsLevelDesigner1, 0, 450, .centerHorizontal)

        button?.draw(video)
    }

    func exit() {}
}
