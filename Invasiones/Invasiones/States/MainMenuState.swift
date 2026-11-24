//
//  MainMenuState.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of EstadoMenuPpal.cs — main menu with entry animation.
//

import Foundation

/// Displays the main menu and directs the player to the option they select.
/// The menu slides up from the bottom of the screen on first entry.
final class MainMenuState: State {

    let stateMachine: StateMachine
    private var background: Surface?
    /// Used for countdowns.
    private var count = 0

    // MARK: - Constants
    /// Number of ticks to wait before the menu starts sliding into view.
    private let ticksUntilMenuAppears = 20
    /// Pixels the menu moves upward per tick during its entry animation.
    private let menuSlideSpeed = 5

    // MARK: - Menu items
    private enum Item: Int {
        case newGame = 0
        case help    = 1
        case options = 2
        case credits = 3
        case quit    = 4
    }

    private enum Constants {
        static let mainMenuYOffset = 50
    }

    // MARK: - Declarations
    private var menu: Menu?
    /// The final Y position the menu should reach after animating in.
    private var menuTargetY: Int = 0
    /// The current Y position of the menu during animation.
    private var posY: Int = 0
    /// `true` on the first entry so the slide-in animation only initialises once.
    private var firstBuild: Bool = true

    // MARK: - Initializer
    init(_ sm: StateMachine) {
        stateMachine = sm
        firstBuild = true
    }

    // MARK: - Methods

    func start() {
        background = ResourceManager.shared.getImage(Res.IMG_SPLASH)

        Mouse.shared.cursor = ResourceManager.shared.getImage(Res.IMG_CURSOR)
        Mouse.shared.showCursor()

        let newMenu = Menu(
            image: nil,
            itemCount: 5,
            x: 0,
            y: Video.height - Constants.mainMenuYOffset,
            anchor: .centerHorizontal
        )

        newMenu.addItem(index: Item.newGame.rawValue,  label: .menuNewGame, flag: Menu.Constants.itemVisible)
        newMenu.addItem(index: Item.help.rawValue,     label: .menuHelp,       flag: Menu.Constants.itemVisible)
        newMenu.addItem(index: Item.options.rawValue,  label: .menuOptions,    flag: Menu.Constants.itemVisible)
        newMenu.addItem(index: Item.credits.rawValue,  label: .menuCredits,    flag: Menu.Constants.itemVisible)
        newMenu.addItem(index: Item.quit.rawValue,     label: .menuExit,       flag: Menu.Constants.itemVisible)

        if firstBuild {
            firstBuild = false
            menuTargetY = Video.height - newMenu.frame.height - Constants.mainMenuYOffset
            posY = Video.height + newMenu.frame.height + Constants.mainMenuYOffset
            newMenu.setPosition(x: 0, y: Video.height + 15, anchor: .centerHorizontal)
        }

        newMenu.font = ResourceManager.shared.fonts[FontConstants.menuFont]
        menu = newMenu

        Sound.shared.stop(Res.SFX_BATALLA)
        Sound.shared.play(id: Res.SFX_SPLASH, loop: -1)
    }

    func update() {
        guard let menu = menu else { return }

        count += 1
        if count > ticksUntilMenuAppears {
            if posY > menuTargetY {
                posY -= menuSlideSpeed
            }
            menu.setPosition(x: 0, y: posY, anchor: .centerHorizontal)
        }

        guard let index = menu.update(), let item = Item(rawValue: index) else { return }

        switch item {
        case .newGame:
            stateMachine.setNextState(.game)
        case .help:
            stateMachine.setNextState(.help)
        case .options:
            stateMachine.setNextState(.options)
        case .credits:
            stateMachine.setNextState(.credits)
        case .quit:
            stateMachine.setNextState(.quit)
        }
    }

    func draw(_ video: Video) {
        video.draw(background, 0, 0, [])
        menu?.draw(video)
    }

    func exit() {
        menu = nil
    }
}
