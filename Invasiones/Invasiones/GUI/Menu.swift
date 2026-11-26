//
//  Menu.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Menu.cs — vertical menu with mouse-selectable items.
//

import Foundation

final class Menu {

    // MARK: - Constants
    enum Constants {
        static let maxItemCount = 15
        static let itemVisible  = 1 << 1
        static let itemHidden   = 1 << 2
        static let itemHover    = 1 << 3
        static let itemSelected = 1 << 4
    }

    // MARK: - Declarations
    var frame = Frame()
    var font:  GameFont?
    var image: Surface?

    /// Per-item state flags (`Constants.item*`).
    private var itemFlags: [Int]
    /// Per-item label.
    private var itemLabels: [StringID?]
    private var itemCount: Int = 0
    private var buttonWidth: Int = 160
    private var buttonHeight: Int = 26
    private var lineSpacing: Int = 1
    private var originalY: Int
    private var originalX: Int
    private var anchor: Anchor

    // MARK: - Initializer
    init(image img: Surface?, itemCount: Int, x: Int, y: Int, anchor anch: Anchor) {
        itemFlags = Array(repeating: 0, count: Constants.maxItemCount)
        itemLabels = Array(repeating: nil, count: Constants.maxItemCount)
        originalX = x
        originalY = y
        anchor = anch
        image = img
    }

    // MARK: - Methods

    func draw(_ video: Video) {
        if let img = image {
            video.draw(img, frame.posX, frame.posY - 6, [])
        } else {
            let padding = 6
            let totalHeight = (buttonHeight + lineSpacing) * itemCount - lineSpacing
            video.color = Theme.menus
            video.fillRoundedRect(
                frame.posX - padding, frame.posY - padding,
                buttonWidth + padding * 2,
                totalHeight + padding * 2,
                10,
                Theme.alpha
            )
        }

        var y = frame.posY
        for i in 0..<itemCount {
            let flags = itemFlags[i]
            if flags != Constants.itemHidden {
                if (flags & Constants.itemHover) != 0 {
                    video.color = GameColor.black
                    video.fillRect(frame.posX, y, buttonWidth, buttonHeight)
                }
                video.font = font
                video.fontColor = Theme.text
                if let label = itemLabels[i] {
                    video.write(
                        label,
                        frame.posX - (Video.width >> 1) + (buttonWidth >> 1),
                        y          - (Video.height >> 1) + (buttonHeight >> 1),
                        .center
                    )
                }
                y += lineSpacing + buttonHeight
            }
        }
    }

    @discardableResult
    func update() -> Int? {
        var selectedItem: Int?
        var y = frame.posY

        for i in 0..<itemCount {
            let flags = itemFlags[i]
            if flags != Constants.itemHidden {
                let mx = Int(Mouse.shared.x)
                let my = Int(Mouse.shared.y)
                if mx > frame.posX && mx < frame.posX + buttonWidth && my > y && my < y + buttonHeight {
                    itemFlags[i] |= Constants.itemHover
                    if Mouse.shared.pressedButtons.contains(Mouse.Constants.leftButton) {
                        itemFlags[i] |= Constants.itemSelected
                        selectedItem = i
                    }
                } else {
                    itemFlags[i] &= ~Constants.itemHover
                }
                y += lineSpacing + buttonHeight
            }
        }

        return selectedItem
    }

    func setPosition(x: Int, y: Int, anchor anch: Anchor) {
        originalX = x
        frame.posX = x
        originalY = y
        frame.posY = y
        anchor = anch

        if anchor.contains(.centerHorizontal) {
            frame.posX = (Video.width >> 1) - (buttonWidth >> 1) + originalX
        }
        if anchor.contains(.centerVertical) {
            frame.posY = (Video.height >> 1) + originalY
                - (((buttonHeight + lineSpacing) * itemCount
                    - lineSpacing) >> 1)
        }
    }

    func addItem(index: Int, label: StringID, flag: Int) {
        guard index <= Constants.maxItemCount - 1 else { return }

        if itemCount == index {
            itemCount += 1
        }
        itemFlags[index] = flag
        itemLabels[index] = label

        if anchor.contains(.centerHorizontal) {
            frame.posX = (Video.width >> 1) - (buttonWidth >> 1) + originalX
        }
        if anchor.contains(.centerVertical) {
            frame.posY = (Video.height >> 1) + originalY
                - (((buttonHeight + lineSpacing) * itemCount
                    - lineSpacing) >> 1)
        }

        frame.height = (buttonHeight + lineSpacing) * itemCount - lineSpacing
        frame.width  = image?.width ?? buttonWidth
    }
}
