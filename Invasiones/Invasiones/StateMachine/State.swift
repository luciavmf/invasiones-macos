//
//  State.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Estado.cs — abstract base class for all game states.
//  In Swift this is a protocol, so a state that misses one of the
//  required methods fails at compile time instead of at runtime.
//

import Foundation

/// A top-level game state driven by a `StateMachine`.
protocol State: AnyObject {

    /// Parent state machine — needed to transition to another state from within.
    var stateMachine: StateMachine { get }

    /// Draws the state onto the given video surface.
    /// - Parameter video: The screen to draw onto.
    func draw(_ video: Video)

    /// Updates the state logic for this frame.
    func update()

    /// Called each time this state becomes active.
    func start()

    /// Called each time this state is exited.
    func exit()
}
