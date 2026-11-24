//
//  Tile.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Tile.cs — data for an individual tile (id, movement cost, count).
//

import Foundation

struct Tile {
    /// What the tile stands for, if it is tagged in its tileset.
    var kind: TileKind?
    var count: Int = 0
    var cost: Int = 0
}
