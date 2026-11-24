//
//  ConfirmationMenu.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of MenuDeConfirmacion.cs — dialog box with two buttons.
//

import Foundation

final class ConfirmationMenu {

    // MARK: - Enum
    enum Selection {
        case left
        case right
    }

    enum Constants {
        static let alpha         = 128
        static let defaultWidth  = 350
        static let defaultHeight = 150
    }

    // MARK: - Declarations
    var frame = Frame(width: Constants.defaultWidth, height: Constants.defaultHeight)
    var label: Int

    private var leftButton:  Button
    private var rightButton: Button

    // MARK: - Initializer
    init(_ lbl: Int, _ boton1: Int, _ boton2: Int) {
        label = lbl
        leftButton  = Button(label: boton1, font: nil)
        leftButton.setPosition(x: 0, y: 0, anchor: [])
        rightButton = Button(label: boton2, font: nil)
        rightButton.setPosition(x: 200, y: 200, anchor: [])
    }

    // MARK: - Methods

    func setPosition(x: Int, y: Int, anchor: Anchor) {
        frame.posX = x
        frame.posY = y
        if anchor.contains(.centerHorizontal) { frame.posX += (Video.width  >> 1) - (frame.width  >> 1) }
        if anchor.contains(.centerVertical) { frame.posY += (Video.height >> 1) - (frame.height >> 1) }

        leftButton.setPosition(
            x: frame.posX + Button.Constants.screenEdgeOffset,
            y: frame.posY + frame.height - leftButton.frame.height - Button.Constants.screenEdgeOffset,
            anchor: []
        )
        rightButton.setPosition(
            x: frame.posX + frame.width - rightButton.frame.width - Button.Constants.screenEdgeOffset,
            y: frame.posY + frame.height - rightButton.frame.height - Button.Constants.screenEdgeOffset,
            anchor: []
        )
    }

    /// Returns the clicked button, or `nil` if neither was clicked this frame.
    @discardableResult
    func update() -> Selection? {
        if leftButton.update()  != 0 { return .left }
        if rightButton.update() != 0 { return .right }
        return nil
    }

    func draw(_ video: Video) {
        video.color = Theme.menus
        video.fillRect(frame.posX, frame.posY, frame.width, frame.height, Constants.alpha)

        video.font = ResourceManager.shared.fonts[FontConstants.menuFont]
        video.fontColor = Theme.text
        video.write(
            label,
            frame.posX - (Video.width >> 1) + (frame.width >> 1),
            frame.posY + frame.height / 5,
            .centerHorizontal
        )

        leftButton.draw(video)
        rightButton.draw(video)
    }
}
