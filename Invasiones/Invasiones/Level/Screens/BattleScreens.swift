//
//  BattleScreens.swift
//  Invasiones
//
//  The screens shown over the battle: loading, the intro, the objectives popup, and
//  the won and lost screens. Port of the drawing in Episodio.cs and its partial files.
//  Which screen is shown, and when, is decided by BattleFlow.
//

/// The black screen shown while the battle loads.
enum LoadingScreen {
    static let titleY = 200

    static func draw(_ video: Video, resources: ResourceManager = .shared) {
        video.fillRect(.black)
        video.color = Theme.title
        video.font = resources.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.loading, 0, titleY, .centerHorizontal)
    }
}

/// The battle's intro: a box with a page of text and a "Next" button.
final class IntroScreen {
    enum Constants {
        /// Space left around the intro box.
        static let border = 100
        static let buttonY = 510
    }

    private var button = Button(label: .next, font: nil)
    private let hudHeight: Int
    private let resources: ResourceManager

    init(hudHeight: Int, resources: ResourceManager = .shared) {
        self.hudHeight = hudHeight
        self.resources = resources
        button.setPosition(x: 0, y: Constants.buttonY, anchor: .centerHorizontal)
    }

    /// Whether "Next" was pressed this frame.
    func update() -> Bool {
        button.update() != 0
    }

    /// Draws a page of text; the first page uses the title font.
    func draw(_ video: Video, page: Int, text: StringID?) {
        video.color = Theme.objectivesText
        video.fillRect(
            0, -(hudHeight >> 1),
            Video.width - (Constants.border << 1),
            Video.height - (Constants.border << 1) - hudHeight,
            Theme.alpha,
            .center
        )

        let font = page == 0 ? FontConstants.titleFont : FontConstants.objectivesFont
        video.font = resources.fonts[font]
        video.fontColor = Theme.text
        if let text {
            video.write(text, 0, -(hudHeight >> 1), .center)
        }
        button.draw(video)
    }
}

/// The objectives popup: a box with the "Objectives" title, the objective's text and an "Accept" button.
final class ObjectivesScreen {
    enum Constants {
        static let boxWidth = 600
        static let boxHeight = 270
        static let buttonY = 70
    }

    private var button = Button(label: .accept, font: nil)
    private let hudHeight: Int
    private let resources: ResourceManager

    init(hudHeight: Int, resources: ResourceManager = .shared) {
        self.hudHeight = hudHeight
        self.resources = resources
        button.setPosition(x: 0, y: Constants.buttonY, anchor: .center)
    }

    /// Whether "Accept" was pressed this frame.
    func update() -> Bool {
        button.update() != 0
    }

    func draw(_ video: Video, text: StringID?) {
        video.color = Theme.objectivesText
        video.fillRect(0, -(hudHeight / 2), Constants.boxWidth, Constants.boxHeight, Theme.alpha, .center)

        video.font = resources.fonts[FontConstants.titleFont]
        video.fontColor = Theme.text
        video.write(.objectives, 0, -(hudHeight / 2) - Constants.boxHeight / 2 + 50, .center)

        video.font = resources.fonts[FontConstants.objectivesFont]
        video.fontColor = Theme.text
        if let text {
            video.write(text, 0, -(hudHeight >> 1) + 30, .center)
        }

        button.draw(video)
    }
}

/// "You won", with a "Next" button where the intro has it.
final class WonScreen {
    private var button = Button(label: .next, font: nil)
    private let resources: ResourceManager

    init(resources: ResourceManager = .shared) {
        self.resources = resources
        button.setPosition(x: 0, y: IntroScreen.Constants.buttonY, anchor: .centerHorizontal)
    }

    /// Whether "Next" was pressed this frame.
    func update() -> Bool {
        button.update() != 0
    }

    func draw(_ video: Video) {
        button.draw(video)
        video.font = resources.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.youWon, 0, 0, .center)
    }
}

/// "You lost", then the menu asking whether to play again.
final class LostScreen {
    private let menu = ConfirmationMenu(.playAgain, .no, .yes)
    private let resources: ResourceManager

    init(resources: ResourceManager = .shared) {
        self.resources = resources
        menu.setPosition(x: 0, y: 0, anchor: .center)
    }

    /// The answer chosen this frame: `true` to play again, `false` to quit, `nil` for none.
    func update() -> Bool? {
        switch menu.update() {
        case .left: false
        case .right: true
        case nil: nil
        }
    }

    func draw(_ video: Video, showsMenu: Bool) {
        video.font = resources.fonts[FontConstants.titleFont]
        video.fontColor = Theme.title
        video.write(.youLost, 0, -100, .center)
        if showsMenu {
            menu.draw(video)
        }
    }
}
