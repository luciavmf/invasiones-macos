//
//  AnimationID.swift
//  Invasiones
//
//  Identifiers of the standalone animations in data/res.json.
//  Replace the Res.ANIM_* integer constants (port of Res.cs).
//

/// A standalone animation. The raw value is its position in the `anims` list of `data/res.json`.
enum AnimationID: Int, CaseIterable {
    case rings
    case guideArrow
    case fire1
    case fire2
    case helpSelect
    case helpMove
    case helpAttack
    case helpObjective
    case helpScroll
    case helpHud
    case helpHeal
    case helpTips
    case helpWin

    /// The help screen animations, in the order of `HelpState.Substate`
    /// (matching `StringID.helpPages`).
    static let helpScreens: [AnimationID] = [
        .helpSelect, .helpMove, .helpAttack, .helpObjective, .helpScroll,
        .helpHud, .helpHeal, .helpTips, .helpWin,
    ]
}
