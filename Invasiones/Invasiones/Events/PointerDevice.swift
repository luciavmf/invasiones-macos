//
//  PointerDevice.swift
//  Invasiones
//
//  The parts of the mouse that player input reads, so tests can use a fake pointer.
//

internal import CoreGraphics

protocol PointerDevice: AnyObject {
    /// Position in screen coordinates (top-left origin).
    var x: CGFloat { get }
    var y: CGFloat { get }
    /// Buttons held down (`Mouse.Constants`).
    var pressedButtons: [Int] { get }
    /// The rectangle of the current or last drag.
    var dragRect: CGRect { get }
    func isDragging() -> Bool
    /// `true` on the frame a drag ends.
    func didFinishDragging() -> Bool
    /// Treats a button as released, so a click is only handled once.
    func releaseButton(_ button: Int)
    var cursor: Surface? { get set }
}

extension Mouse: PointerDevice {}
