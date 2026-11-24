//
//  Anchor.swift
//  Invasiones
//
//  Positioning flags shared by Video, Surface, Animation and the GUI components.
//  Replaces the C# integer flags (Superficie.H_CENTRO / V_CENTRO) combined with `|`.
//

/// Where to place something relative to the screen. An empty set (`[]`) means
/// the coordinates are used as given; each flag centres on that axis and then
/// offsets by the given coordinate.
struct Anchor: OptionSet {
    let rawValue: Int

    /// Centre horizontally on the screen.
    static let centerHorizontal = Anchor(rawValue: 1 << 0)
    /// Centre vertically on the screen.
    static let centerVertical = Anchor(rawValue: 1 << 1)
    /// Centre on both axes.
    static let center: Anchor = [.centerHorizontal, .centerVertical]
}
