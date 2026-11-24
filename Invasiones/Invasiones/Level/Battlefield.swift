//
//  Battlefield.swift
//  Invasiones
//
//  The map and camera of the battle being played, passed to everything placed on
//  the map. Replaces the static MapObject.map, MapObject.camera and Group.map.
//

/// What map objects need from the map: walkability and the size of a map tile.
/// `Map` provides it in the game; tests use small hand-made grids.
protocol BattleMap: WalkableGrid {
    /// Width of a map tile in pixels.
    var tileWidth: Int { get }
    /// Height of a map tile in pixels.
    var tileHeight: Int { get }
}

extension Map: BattleMap {}

/// The map and camera of the current battle. `Episode` creates them; map objects,
/// units and groups receive this when they are created.
struct Battlefield {
    let map: any BattleMap
    let camera: Camera
}
