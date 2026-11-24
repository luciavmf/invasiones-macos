//
//  ImageID.swift
//  Invasiones
//
//  Identifiers of the images and font files listed in data/res.json.
//  Replace the Res.IMG_* and Res.FNT_* integer constants (port of Res.cs).
//

/// A standalone image. The raw value is its position in the `imagenes` list of `data/res.json`.
enum ImageID: Int, CaseIterable {
    case swordCursor
    case infirmaryCursor
    case cursor
    case arrow
    case icon
    case logo
    case splash
    case background
    case greyTile
    case hud
}

/// A font file. The raw value is its position in the `fuentes` list of `data/res.json`.
enum FontFamily: Int, CaseIterable {
    case sans
    case lblack
}
