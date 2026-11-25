//
//  Tileset.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Tileset.cs — loads and queries a TSX tileset (Tiled format).
//

import Foundation
import SpriteKit

final class Tileset {

    // MARK: - Declarations
    var firstGid: Int = 0
    private(set) var id: TilesetID = .debug
    fileprivate(set) var tileWidth: Int = 0
    fileprivate(set) var tileHeight: Int = 0
    fileprivate(set) var name: String = "" {
        didSet { id = TilesetID(tsxName: name) }
    }
    fileprivate(set) var image: Surface? {
        didSet {
            if let img = image, tileWidth > 0, tileHeight > 0 {
                let count = (img.height / tileHeight) * (img.width / tileWidth)
                tiles = Array(repeating: nil, count: count)
            }
        }
    }
    var tiles: [Tile?] = []
    private var textureCache: [Int: SKTexture] = [:]

    // MARK: - Initializer
    init() {}

    // MARK: - Loading

    /// Loads the tileset from the given TSX path.
    func load(_ tilesetPath: String) throws {
        guard let parser = XMLParser(contentsOf: URL(fileURLWithPath: tilesetPath)) else {
            throw GameError.fileNotFound("Tileset: cannot open \(tilesetPath)")
        }
        let delegate = TilesetXMLDelegate(tileset: self, basePath: tilesetPath)
        parser.delegate = delegate
        let ok = parser.parse()
        withExtendedLifetime(delegate) {}
        if !ok {
            throw GameError.parsingFailed("Tileset: failed to parse \(tilesetPath)")
        }
    }

    // MARK: - Helpers

    /// Returns the (x, y, w, h) rectangle within the tileset image for the given local tile ID.
    func getTileRect(_ tileId: Int) -> (x: Int, y: Int, w: Int, h: Int) {
        guard let img = image, tileWidth > 0, tileHeight > 0 else { return (0, 0, 0, 0) }
        let cols = img.width / tileWidth
        let col = cols > 0 ? tileId % cols : 0
        let row = cols > 0 ? tileId / cols : 0
        return (col * tileWidth, row * tileHeight, tileWidth, tileHeight)
    }

    /// Returns a cached SKTexture sub-rect for the given local tile ID.
    /// The texture is created once and reused every frame.
    func getTileTexture(_ tileId: Int) -> SKTexture? {
        if let cached = textureCache[tileId] { return cached }
        guard let tex = image?.texture, tileWidth > 0, tileHeight > 0 else { return nil }
        let texW = tex.size().width
        let texH = tex.size().height
        guard texW > 0, texH > 0 else { return nil }
        let cols = max(1, Int(texW) / tileWidth)
        let col  = tileId % cols
        let row  = tileId / cols
        let nx = CGFloat(col * tileWidth) / texW
        let ny = 1.0 - CGFloat((row + 1) * tileHeight) / texH
        let nw = CGFloat(tileWidth) / texW
        let nh = CGFloat(tileHeight) / texH
        let subTex = SKTexture(rect: CGRect(x: nx, y: ny, width: nw, height: nh), in: tex)
        subTex.filteringMode = .nearest
        textureCache[tileId] = subTex
        return subTex
    }

}

// MARK: - Internal XML parser

private final class TilesetXMLDelegate: NSObject, XMLParserDelegate {

    private weak var tileset: Tileset?
    private let basePath: String
    private var currentTileId: Int?

    init(tileset: Tileset, basePath: String) {
        self.tileset = tileset
        self.basePath = (basePath as NSString).deletingLastPathComponent
    }

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        guard let ts = tileset else { return }

        switch name {
        case "tileset":
            if let n = attributes["name"] { ts.name = n }
            if let w = attributes["tilewidth"]  { ts.tileWidth  = Int(w) ?? 0 }
            if let h = attributes["tileheight"] { ts.tileHeight = Int(h) ?? 0 }

        case "image":
            if let src = attributes["source"] {
                let fullPath = Utils.getPath(
                    (basePath as NSString).appendingPathComponent(src))
                    ?? Utils.getPath(
                        (ResourcePath.scenariosPath as NSString).appendingPathComponent(src))
                if let path = fullPath {
                    ts.image = ResourceManager.shared.getImage(path)
                } else {
                    Log.shared.error("Tileset: image not found \(src)")
                }
            }

        case "tile":
            if let idStr = attributes["id"], let idx = Int(idStr) {
                currentTileId = idx
                if idx < ts.tiles.count {
                    ts.tiles[idx] = Tile()
                }
            }

        case "property":
            guard let tileId = currentTileId, tileId >= 0, tileId < ts.tiles.count else { break }
            let propName = (attributes["name"] ?? "").lowercased()
            let propValue = attributes["value"] ?? ""
            if propName == "id" || propName == "unidad" {
                if let kind = TileKind(propertyValue: propValue) {
                    ts.tiles[tileId]?.kind = kind
                }
            } else if propName == "cantidad" {
                ts.tiles[tileId]?.count = Int(propValue) ?? 0
            }

        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        if name == "tile" { currentTileId = nil }
    }
}
