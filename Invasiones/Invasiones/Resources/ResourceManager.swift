//
//  ResourceManager.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of AdministradorDeRecursos.cs — singleton that loads and caches all game resources.
//  SDL_Surface → SKTexture, SDL_ttf → NSFont, SDL_mixer paths → strings for AVAudioEngine.
//

import SpriteKit

final class ResourceManager {

    // MARK: - Singleton
    static let shared = ResourceManager()

    // MARK: - Declarations
    /// Image cache indexed by id (Int) or name (String).
    private var imageById: [ImageID: Surface] = [:]
    private var imageByName: [String: Surface] = [:]

    /// Resolved (absolute) paths read from res.json.
    private(set) var fontPaths: [String?] = []
    private(set) var imagePaths: [String?] = []
    private(set) var scenarioPaths: [String?] = []
    private(set) var soundPaths: [String?] = []
    private(set) var unitPaths: [String?] = []

    /// Loaded fonts (one per Definitions.FNT variant).
    private(set) var fonts: [FontIndex: GameFont] = [:]

    /// Loaded soldier sprites.
    private(set) var sprites: [SpriteID: Sprite] = [:]

    /// Loaded standalone animations.
    private(set) var animations: [AnimationID: Animation] = [:]

    /// The stats of each unit type, read from its CSV file.
    private(set) var unitStats: [UnitType: UnitStats] = [:]

    // MARK: - Initializer (private)
    private init() {}

    func dispose() {
        fonts.values.forEach { $0.dispose() }
        fonts.removeAll()
        imageById.removeAll()
        imageByName.removeAll()
    }

    // MARK: - Load paths from res.json

    func loadResourcePaths() throws {
        let res = try decodeResJSON()

        fontPaths = res.fuentes.map { Utils.getPath($0) }
        imagePaths = res.imagenes.map { Utils.getPath($0) }
        scenarioPaths = (res.escenarios.tilesets + res.escenarios.mapas).map { Utils.getPath($0) }
        soundPaths = res.sonidos.sfx.map { Utils.getPath($0) }
        unitPaths = res.unidades.map { Utils.getPath($0.file) }

        let hasErrors = fontPaths.contains(where: { $0 == nil })
                      || imagePaths.contains(where: { $0 == nil })
        if hasErrors {
            throw GameError.invalidResource("One or more files could not be loaded.")
        }
    }

    // MARK: - Images

    /// Gets (and caches) the image by relative or absolute file name.
    func getImage(_ name: String) -> Surface? {
        if let cached = imageByName[name] { return cached }
        // If it's already an absolute path that exists, use it directly.
        let path: String
        if name.hasPrefix("/") && FileManager.default.fileExists(atPath: name) {
            path = name
        } else {
            guard let resolved = Utils.getPath(name) else { return nil }
            path = resolved
        }
        let sup = Surface(path: path)
        imageByName[name] = sup
        return sup
    }

    /// Gets (and caches) the image listed in res.json.
    func getImage(_ id: ImageID) -> Surface? {
        if let cached = imageById[id] { return cached }
        guard let path = imagePaths[safe: id.rawValue] ?? nil else { return nil }
        let sup = Surface(path: path)
        imageById[id] = sup
        return sup
    }

    /// Same as getImage(id) — in the original it loaded with an explicit alpha channel;
    /// in SpriteKit all PNG textures support alpha automatically.
    func getAlphaImage(_ id: ImageID) -> Surface? {
        return getImage(id)
    }

    func getCopyOfImage(_ name: String) -> Surface? {
        guard let orig = getImage(name) else { return nil }
        return Surface(copying: orig)
    }

    // MARK: - Fonts

    func loadFonts() throws {
        guard fonts.isEmpty else { return }

        fonts[.sans12] = GameFont(family: .sans, size: 12)
        fonts[.sans14] = GameFont(family: .sans, size: 14)
        fonts[.sans18] = GameFont(family: .sans, size: 18)
        fonts[.sans20] = GameFont(family: .sans, size: 20)
        fonts[.sans24] = GameFont(family: .sans, size: 24)
        fonts[.sans28] = GameFont(family: .sans, size: 28)
        fonts[.lblack12] = GameFont(family: .lblack, size: 12)
        fonts[.lblack14] = GameFont(family: .lblack, size: 14)
        fonts[.lblack18] = GameFont(family: .lblack, size: 18)
        fonts[.lblack20] = GameFont(family: .lblack, size: 20)
        fonts[.lblack28] = GameFont(family: .lblack, size: 28)

        if fonts[.sans12] == nil {
            throw GameError.invalidResource("Could not load the SANS12 font.")
        }
    }

    // MARK: - Unit types

    func loadUnitTypes() {
        unitStats = [:]
        for type in UnitType.allCases {
            guard let path = unitPaths[safe: type.rawValue] ?? nil,
                  let csv = try? String(contentsOfFile: path, encoding: .utf8) else {
                Log.shared.error("Unit: failed to read unit \(type)")
                continue
            }
            unitStats[type] = UnitStats(csv: csv)
        }
    }

    // MARK: - Sprites (reads "sprites" section of res.json)

    func readSpriteInfo() throws {
        let res = try decodeResJSON()

        sprites = [:]
        for (i, sprJSON) in res.sprites.enumerated() {
            guard let id = SpriteID(rawValue: i) else { break }
            let anims = sprJSON.animpaks.map { pak -> Animation in
                let img = pak.image
                let path = Utils.getPath(img.path) ?? ""
                return Animation(idx: 0, path: path, ticks: img.frameticks,
                                 frameWidth: img.framewidth, frameHeight: img.frameheight,
                                 offsetX: img.offsetX, offsetY: img.offsetY)
            }
            let spr = Sprite()
            spr.reserveSlots(anims.count)
            for (j, anim) in anims.enumerated() {
                spr.addAnimation(i: j, anim: anim)
            }
            try? spr.load()
            sprites[id] = spr
        }
    }

    // MARK: - Animations (reads "anims" section of res.json)

    func readAnimationInfo() throws {
        let res = try decodeResJSON()

        animations = [:]
        for (i, animJSON) in res.anims.enumerated() {
            guard let id = AnimationID(rawValue: i) else { break }
            let path = Utils.getPath(animJSON.imagepath) ?? ""
            animations[id] = Animation(idx: 0, path: path, ticks: animJSON.frameticks,
                                      frameWidth: animJSON.framewidth, frameHeight: animJSON.frameheight,
                                      offsetX: animJSON.offsetX, offsetY: animJSON.offsetY)
        }
    }

    // MARK: - Private JSON decoding

    private func decodeResJSON() throws -> ResJSON {
        guard let path = Utils.getPath(ResourcePath.resourcesPath) else {
            throw GameError.fileNotFound("File \(ResourcePath.resourcesPath) not found.")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        do {
            return try JSONDecoder().decode(ResJSON.self, from: data)
        } catch {
            throw GameError.parsingFailed("ResourceManager: failed to parse \(ResourcePath.resourcesPath): \(error).")
        }
    }
}

// MARK: - res.json Codable model

private struct ResJSON: Decodable {

    struct Scenarios: Decodable {
        let tilesets: [String]
        let mapas: [String]
    }

    struct Sounds: Decodable {
        let sfx: [String]
    }

    struct UnitFile: Decodable {
        let name: String
        let file: String
    }

    struct AnimationImage: Decodable {
        let path: String
        let framewidth: Int
        let frameheight: Int
        let frameticks: Int
        let offsetX: Int
        let offsetY: Int
    }

    struct Animpak: Decodable {
        let name: String
        let image: AnimationImage
    }

    struct SpriteJSON: Decodable {
        let name: String
        let animpaks: [Animpak]
    }

    struct AnimJSON: Decodable {
        let name: String
        let imagepath: String
        let framewidth: Int
        let frameheight: Int
        let offsetX: Int
        let offsetY: Int
        let frameticks: Int
    }

    let fuentes: [String]
    let escenarios: Scenarios
    let sonidos: Sounds
    let imagenes: [String]
    let unidades: [UnitFile]
    let sprites: [SpriteJSON]
    let anims: [AnimJSON]
}
