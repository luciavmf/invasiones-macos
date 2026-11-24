//
//  TilesetID.swift
//  Invasiones
//
//  Identifiers of the map tilesets and tile kinds.
//  Replace the Res.TLS_*, Res.MAP_* and Res.TILE_* integer constants (port of Res.cs).
//

/// A map tileset. The raw value is its position in the `escenarios.tilesets` list of `data/res.json`.
enum TilesetID: Int, CaseIterable {
    case debug
    case grass
    case dirt
    case water
    case trees
    case units
    case rocks
    case textures
    case rocks2
    case infirmary
    case buildings
    case invalidated
    case objectives
    case fort

    /// The tileset with the given `name` attribute in its .tsx file.
    ///
    /// "debug" and "objetivos" are not listed, as in the original: they fall back
    /// to `.debug`, which hides their tiles when drawn as obstacles.
    init(tsxName: String) {
        switch tsxName.lowercased() {
        case "tierra": self = .dirt
        case "agua": self = .water
        case "pasto": self = .grass
        case "arboles": self = .trees
        case "unidades": self = .units
        case "piedras": self = .rocks
        case "texturas": self = .textures
        case "piedras2": self = .rocks2
        case "enfermeria": self = .infirmary
        case "edificios": self = .buildings
        case "invalidados": self = .invalidated
        case "fuerte": self = .fort
        default: self = .debug
        }
    }
}

/// What a tagged tile in a tileset stands for (its `id` / `unidad` property in the .tsx file).
enum TileKind {
    /// Debug tileset: marks a tile's neighbours.
    case neighbourTiles
    /// Debug tileset: marks the path a unit will follow.
    case pathToFollow
    /// Units tileset: where Patricio soldiers start.
    case patricio
    /// Units tileset: where British soldiers start.
    case british
    /// Invalidated tileset: an infirmary, where units heal.
    case infirmary
    /// Invalidated tileset: a house.
    case house

    init?(propertyValue: String) {
        switch propertyValue {
        case "TILES_VECINOS": self = .neighbourTiles
        case "CAMINO_A_SEGUIR": self = .pathToFollow
        case "PATRICIO": self = .patricio
        case "INGLES": self = .british
        case "ENFERMERIA": self = .infirmary
        case "CASA": self = .house
        default: return nil
        }
    }
}
