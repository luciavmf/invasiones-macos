//
//  UnitStats.swift
//  Invasiones
//
//  A unit type's stats, read from its unidades/*.csv file.
//

import Foundation

/// The stats every unit of a type starts with. The defaults are the ones the CSV parser
/// falls back to for a missing or invalid value.
struct UnitStats: Equatable {
    /// The soldier sprite. `nil` when the file names none.
    var sprite: SpriteID?
    /// Movement speed, in world pixels per frame.
    var speed = 2
    /// Maximum health points; units start with full health.
    var resistancePoints = 100
    /// Damage dealt by each shot (always in full; there is no accuracy roll).
    var attackPoints = 10
    /// Tile radius within which enemy units are seen.
    var visibility = 10
    /// Accuracy. Loaded but never used, as in the original.
    var aim = 5
    /// Tile distance from which the unit can shoot.
    var attackRange = 5
    /// Frames between shots.
    var attackInterval = 30
    /// The name shown in the HUD.
    var name = ""
    /// The image file of the avatar shown in the HUD.
    var avatar: String?
    /// Health points restored per recovery while healing.
    var recoveryPoints = 20
    /// Frames between recoveries while healing.
    var ticksPerRecovery = 50

    init() {}

    /// Parses a unit CSV file: one `key;value` pair per line. The keys are Spanish, as in the data files;
    /// unknown keys (like `Tipo`) are ignored.
    init(csv: String) {
        for line in csv.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ";", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "Sprite": sprite = SpriteID(csvName: value) ?? .british
            case "Velocidad": speed = Int(value) ?? 2
            case "Puntos_Resistencia": resistancePoints = Int(value) ?? 100
            case "Puntos_Ataque": attackPoints = Int(value) ?? 10
            case "Visibilidad": visibility = Int(value) ?? 10
            case "Punteria": aim = Int(value) ?? 5
            case "Alcance_Tiro": attackRange = Int(value) ?? 5
            case "Intervalo_Entre_Ataques": attackInterval = Int(value) ?? 30
            case "Nombre": name = value
            case "Avatar": avatar = value
            case "Puntos_De_Recuperacion": recoveryPoints = Int(value) ?? 20
            case "Ticks_Entre_Recuparacion": ticksPerRecovery = Int(value) ?? 50
            default: break
            }
        }
    }
}
