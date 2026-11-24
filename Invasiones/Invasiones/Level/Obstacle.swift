//
//  Obstacle.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Obstaculo.cs — static obstacle on the map (tree, building, rock).
//

import Foundation

/// A static obstacle on the map (tree, building, rock, etc.) drawn from a tileset sprite sheet.
final class Obstacle: MapObject {

    // MARK: - Declarations
    /// The frame index within the tileset image.
    private var index: Int = 0
    /// Whether the obstacle is a building, which changes how it is drawn.
    private var isBuilding: Bool = false

    // MARK: - Initializer
    /// Creates an obstacle from a tileset at tile position (i, j).
    /// - Parameters:
    ///   - idx: The frame index within the tileset.
    ///   - i: The tile column (i coordinate).
    ///   - j: The tile row (j coordinate).
    ///   - tileset: The tileset that contains this obstacle's image.
    ///   - battlefield: The map and camera the obstacle is placed on.
    init(index idx: Int, i: Int, j: Int, tileset: Tileset, battlefield: Battlefield) {
        super.init(battlefield: battlefield)
        index = idx

        frameHeight = Int(tileset.tileHeight)
        frameWidth = Int(tileset.tileWidth)

        physicalTilePos = (i, j)
        image = tileset.image

        let p = tileToWorld(i: i, j: j)
        worldPos = p

        if tileset.id == .buildings ||
           tileset.id == .infirmary ||
           tileset.id == .fort {
            isBuilding = true
        }

        if tileset.id == .debug {
            image = nil
        }

        updateScreenPos()
    }

    // MARK: - Override

    @discardableResult
    override func update() -> Bool {
        updateScreenPos()
        return false
    }

    override func draw(_ video: Video) {
        guard let img = image, let map = battlefield?.map else { return }
        img.setClip(x: index * frameWidth, y: 0, w: frameWidth, h: frameHeight)
        if isBuilding {
            video.draw(img, x, y - frameHeight + map.tileHeight / 2, [])
        } else {
            video.draw(img,
                      x - frameWidth / 2 + map.tileWidth / 2,
                      y - frameHeight  + map.tileHeight / 2,
                      [])
        }
    }
}
