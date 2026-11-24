//
//  OptionsState.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Options screen — language selection and sound toggle via radio buttons.
//

import Foundation

final class OptionsState: State {

    let stateMachine: StateMachine
    private var background: Surface?
    private var button: Button?

    init(_ sm: StateMachine) {
        stateMachine = sm
    }

    // MARK: - Layout
    private enum SoundLayout {
        static let labelY   = 200
        static let startY   = 228
        static let rowHeight = 36
        static let hoverX   = 460
        static let hoverW   = 190
        static let indX     = 472
        static let indSize  = 12
        static let textX    = 496
    }

    private enum RadioLayout {
        static let startY    = 325
        static let rowHeight = 36
        static let hoverX    = 460
        static let hoverW    = 190
        static let indX      = 472
        static let indSize   = 12
        static let textX     = 496
    }

    // MARK: - State
    private var hoveredLanguage: Language?
    private var soundRowHovered = false

    // MARK: - Lifecycle

    func start() {
        background = ResourceManager.shared.getImage(Res.IMG_FONDO)
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

        let mx = Int(Mouse.shared.x)
        let my = Int(Mouse.shared.y)

        // Sound toggle
        soundRowHovered = mx >= SoundLayout.hoverX
                       && mx <= SoundLayout.hoverX + SoundLayout.hoverW
                       && my >= SoundLayout.startY
                       && my <  SoundLayout.startY + SoundLayout.rowHeight
        if soundRowHovered && Mouse.shared.pressedButtons.contains(Mouse.Constants.leftButton) {
            Mouse.shared.releaseButton(Mouse.Constants.leftButton)
            Sound.shared.isMuted.toggle()
        }

        // Language selection
        hoveredLanguage = nil
        for (i, lang) in Language.allCases.enumerated() {
            let rowY = RadioLayout.startY + i * RadioLayout.rowHeight
            let inRow = mx >= RadioLayout.hoverX
                     && mx <= RadioLayout.hoverX + RadioLayout.hoverW
                     && my >= rowY
                     && my <  rowY + RadioLayout.rowHeight
            if inRow {
                hoveredLanguage = lang
                if Mouse.shared.pressedButtons.contains(Mouse.Constants.leftButton) {
                    Mouse.shared.releaseButton(Mouse.Constants.leftButton)
                    if Language.current != lang {
                        Language.current = lang
                        try? GameText.loadStrings()
                    }
                }
            }
        }
    }

    func draw(_ video: Video) {
        video.draw(background, 0, 0, [])

        // Title
        video.font = ResourceManager.shared.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(.menuOptions, 0, Layout.titleYPosition, .centerHorizontal)

        // Sound section
        video.font = ResourceManager.shared.fonts[FontConstants.buttonFont]
        video.fontColor = Theme.text
        video.write(.soundLabel, 0, SoundLayout.labelY, .centerHorizontal)

        let indSoundY = SoundLayout.startY + (SoundLayout.rowHeight - SoundLayout.indSize) / 2
        if soundRowHovered {
            video.color = Theme.menus
            video.fillRoundedRect(SoundLayout.hoverX, SoundLayout.startY,
                                  SoundLayout.hoverW, SoundLayout.rowHeight - 2,
                                  4, Theme.alpha)
        }
        video.color = Theme.text
        video.drawRect(SoundLayout.indX, indSoundY, SoundLayout.indSize, SoundLayout.indSize, [])
        if !Sound.shared.isMuted {
            let inset = 3
            video.fillRect(SoundLayout.indX + inset, indSoundY + inset,
                           SoundLayout.indSize - inset * 2, SoundLayout.indSize - inset * 2)
        }
        let soundTextY = SoundLayout.startY + SoundLayout.rowHeight / 2 - Video.height / 2
        let soundLabel = Sound.shared.isMuted ? "Off" : "On"
        video.write(soundLabel, SoundLayout.textX, soundTextY, .centerVertical)

        // Language section
        video.font = ResourceManager.shared.fonts[FontConstants.buttonFont]
        video.fontColor = Theme.text
        video.write(.languageLabel, 0, RadioLayout.startY - 28, .centerHorizontal)

        for (i, lang) in Language.allCases.enumerated() {
            let rowY = RadioLayout.startY + i * RadioLayout.rowHeight
            let indY = rowY + (RadioLayout.rowHeight - RadioLayout.indSize) / 2

            if lang == hoveredLanguage {
                video.color = Theme.menus
                video.fillRoundedRect(RadioLayout.hoverX, rowY,
                                      RadioLayout.hoverW, RadioLayout.rowHeight - 2,
                                      4, Theme.alpha)
            }

            video.color = Theme.text
            video.drawRect(RadioLayout.indX, indY, RadioLayout.indSize, RadioLayout.indSize, [])

            if lang == Language.current {
                let inset = 3
                video.fillRect(RadioLayout.indX + inset, indY + inset,
                               RadioLayout.indSize - inset * 2, RadioLayout.indSize - inset * 2)
            }

            let textY = rowY + RadioLayout.rowHeight / 2 - Video.height / 2
            video.write(lang.displayName, RadioLayout.textX, textY, .centerVertical)
        }

        button?.draw(video)
    }

    func exit() {}
}
