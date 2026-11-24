//
//  Definitions.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Definiciones.cs — global game constants.
//

import Foundation

/// Font slots: keys into `ResourceManager.fonts`.
enum FontIndex {
    case sans12
    case sans14
    case sans18
    case sans20
    case sans24
    case sans28
    case lblack12
    case lblack14
    case lblack18
    case lblack20
    case lblack28
}

/// Eight compass directions used for unit sprite animation.
enum Direction: Int, CaseIterable {
    case north = 0, northEast, east, southEast, south, southWest, west, northWest
}

/// An opaque RGB colour used by the `Video` drawing API, written as 0xRRGGBB
/// like the original C# constants.
struct GameColor: Equatable {
    /// The colour as 0xRRGGBB.
    let rgb: Int

    init(rgb: Int) {
        self.rgb = rgb & 0xFFFFFF
    }

    static let gray        = GameColor(rgb: 0xC8C8C8)
    static let red         = GameColor(rgb: 0xFF0000)
    static let black       = GameColor(rgb: 0x000000)
    static let white       = GameColor(rgb: 0xFFFFFF)
    static let green       = GameColor(rgb: 0x00FF00)
    static let blue        = GameColor(rgb: 0x0000FF)
    static let cyan        = GameColor(rgb: 0x00FFFF)
    static let magenta     = GameColor(rgb: 0xFF00FF)
    static let transparent = magenta
}

/// Colors used in the UI
enum Theme {
    static let menus = GameColor.black
    static let selection = GameColor.red
    static let buttonHover = GameColor.black
    static let text = GameColor.white
    static let alpha = 128
    static let title = GameColor.white
    static let objectivesText = GameColor.black
}

/// Fonts used in the ui
enum FontConstants {
    static let titleFont = FontIndex.lblack28
    static let helpTitleFont = FontIndex.sans24
    static let helpFont = FontIndex.sans18
    static let menuFont = FontIndex.sans20
    static let buttonFont = FontIndex.sans14
    static let objectivesReminderFont = FontIndex.sans14
    static let objectivesFont = FontIndex.sans20
}

/// Layout
enum Layout {
    static let objectivesOffset = 7
    static let objectivesHeight = 22
    /// Y position for all titles.
    static let titleYPosition = 30
}
