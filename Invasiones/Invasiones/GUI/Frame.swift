//
//  Frame.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Note: rename this file to Frame.swift in Xcode.
//

import Foundation

/// Position and size of a GUI component.
struct Frame {
    var posX:   Int = 0
    var posY:   Int = 0
    var width:  Int = 0
    var height: Int = 0

    mutating func setPosition(x: Int, y: Int, anchor: Anchor) {
        posX = x
        posY = y
        if anchor.contains(.centerVertical) { posY += (Video.height >> 1) - (height >> 1) }
        if anchor.contains(.centerHorizontal) { posX += (Video.width  >> 1) - (width  >> 1) }
    }
}
