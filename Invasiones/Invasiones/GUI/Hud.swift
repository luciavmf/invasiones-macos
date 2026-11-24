//
//  Hud.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Hud.cs — in-game HUD info header.
//

import Foundation

final class Hud {

    // MARK: - Position constants
    private enum Constants {
        static let avatarX = 61
        static let avatarY = 11
        static let avatarNameX = 128
        static let avatarNameWidth = 82
        static let avatarNameY = 6
        static let attrsStartX1 = 141
        static let attrsStartX2 = 215
        static let attrsStartX3 = 338
        static let attrsStartY = 25
        static let attrsCountY = 35
        static let attrsEnemyCountX = 705
        static let attrsArgentineCountX = 570
    }

    // MARK: - Declarations
    private var image: Surface?
    private var unitToShow: Unit?
    var enemyCount: Int = 0
    var argentineCount: Int = 0
    private var posY: Int = 0
    private let lineSpacing = 12
    private var tipsWindow: Tips

    // MARK: - Properties
    var selectedUnit: Unit? {
        set { unitToShow = newValue }
        get { unitToShow }
    }

    var height: Int { image?.height ?? 0 }

    // MARK: - Initializer
    init() {
        image = ResourceManager.shared.getImage(Res.IMG_HUD)
        posY = Video.height - (image?.height ?? 0)
        tipsWindow = Tips()
        tipsWindow.setPosition(
            x: ((Video.width - tipsWindow.frame.width) / 2) + 175,
            y: posY - tipsWindow.frame.height - 75,
            anchor: []
        )
    }

    // MARK: - Update
    func update() {
        if let u = unitToShow, u.isDead() {
            unitToShow = nil
        }
        tipsWindow.update()
    }

    // MARK: - Draw
    func draw(_ video: Video) {
        if let img = image {
            // V_FONDO = draws at the bottom
            video.draw(img, 0, posY, [])
        }
        tipsWindow.draw(video)

        video.font = ResourceManager.shared.fonts[.sans12]
        video.fontColor = GameColor.black
        video.write("\(enemyCount)", Constants.attrsEnemyCountX, posY + Constants.attrsCountY, [])
        video.write("\(argentineCount)", Constants.attrsArgentineCountX, posY + Constants.attrsCountY, [])

        video.font = ResourceManager.shared.fonts[.sans12]
        video.fontColor = GameColor.white

        guard let uni = unitToShow else { return }

        if let av = uni.avatar {
            video.draw(av, Constants.avatarX, posY + Constants.avatarY, [])
        }
        video.write(uni.name, Constants.avatarNameX, posY + Constants.avatarNameY, [])

        video.color = GameColor.black

        video.write("\(GameText.text(.range)): \(uni.range)",
                Constants.attrsStartX1, posY + Constants.attrsStartY, [])
        video.write("\(GameText.text(.aim)): \(uni.aim)",
                Constants.attrsStartX1, posY + Constants.attrsStartY + lineSpacing, [])
        video.write("\(GameText.text(.attackPoints)): \(uni.attackPoints)",
                Constants.attrsStartX2, posY + Constants.attrsStartY, [])
        video.write("\(GameText.text(.resistancePoints)): \(uni.health)/\(uni.resistancePoints)",
                Constants.attrsStartX2, posY + Constants.attrsStartY + lineSpacing, [])
        video.write("\(GameText.text(.speed)): \(uni.defaultSpeed)",
                Constants.attrsStartX3, posY + Constants.attrsStartY, [])
        video.write("\(GameText.text(.visibility)): \(uni.visibility)",
                Constants.attrsStartX3, posY + Constants.attrsStartY + lineSpacing, [])
    }
}
