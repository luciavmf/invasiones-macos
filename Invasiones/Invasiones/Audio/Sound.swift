//
//  Sound.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Sonido.cs — playback of sound effects (the game has no background music).
//  SDL_mixer replaced by AVFoundation.
//

import AVFoundation
import Foundation

/// A sound effect. The raw value is its position in the `sonidos.sfx` list of `data/res.json`.
enum SoundID: Int, CaseIterable {
    case splash
    case patricioShot
    case britishShot
    case patricioDeath
    case battle
}

/// Plays and stops sound effects. `Sound` provides it in the game; tests use a fake that records calls.
protocol SoundPlayer: AnyObject {
    func play(id: SoundID, loop: Int)
    func stop(_ id: SoundID)
}

final class Sound: SoundPlayer {

    // MARK: - Singleton
    static let shared = Sound()

    // MARK: - Declarations
    private var players: [SoundID: AVAudioPlayer] = [:]
#if DEBUG
    var isMuted = true { didSet { applyVolume() } }
#else
    var isMuted = false { didSet { applyVolume() } }
#endif

    private init() { }

    /// Applies the current mute state to every loaded player.
    private func applyVolume() {
        let volume: Float = isMuted ? 0 : 1
        players.values.forEach { $0.volume = volume }
    }

    // MARK: - Methods

    func loadAllSounds() {
        let paths = ResourceManager.shared.soundPaths

        for id in SoundID.allCases {
            guard let path = paths[safe: id.rawValue] ?? nil else { continue }
            do {
                let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                player.prepareToPlay()
                player.volume = isMuted ? 0 : 1
                players[id] = player
            } catch {
                Log.shared.error("Sound: failed to load \(path): \(error)")
            }
        }
    }

    /// Plays a sound effect unless it is already playing.
    /// - Parameter loop: Extra repetitions; `-1` loops forever.
    func play(id: SoundID, loop: Int) {
        guard let player = players[id] else {
            Log.shared.warn("Sound: cannot play \(id): not loaded.")
            return
        }
        if player.isPlaying { return }
        player.volume = isMuted ? 0 : 1
        player.numberOfLoops = loop < -1 ? 0 : loop
        player.play()
    }

    /// Stops every sound effect.
    func stopAll() {
        players.values.forEach {
            $0.stop()
            $0.currentTime = 0
        }
    }

    func stop(_ id: SoundID) {
        guard let player = players[id] else { return }
        player.stop()
        player.currentTime = 0
    }
}
