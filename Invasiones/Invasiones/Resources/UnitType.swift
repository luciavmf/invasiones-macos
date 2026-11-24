//
//  UnitType.swift
//  Invasiones
//
//  Identifiers of the soldier types and their sprites in data/res.json.
//  Replace the Res.UNIDAD_* and Res.SPR_* integer constants (port of Res.cs).
//

/// A kind of soldier. The raw value is its position in the `unidades` list of `data/res.json`.
enum UnitType: Int, CaseIterable {
    case patricio
    case british
}

/// A soldier sprite sheet. The raw value is its position in the `sprites` list of `data/res.json`.
enum SpriteID: Int, CaseIterable {
    case patricio
    case british

    /// The sprite named in a unit's CSV file (`Sprite;patricio`), or `nil` if unknown.
    init?(csvName: String) {
        switch csvName {
        case "patricio": self = .patricio
        case "ingles": self = .british
        default: return nil
        }
    }
}
