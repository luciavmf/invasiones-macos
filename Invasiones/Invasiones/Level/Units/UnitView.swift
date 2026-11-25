//
//  UnitView.swift
//  Invasiones
//
//  How a unit looks on screen: its soldier sprite, its health bar while selected,
//  and the hit-tests that use the sprite's size.
//

/// The parts of a sprite a unit view uses, so tests can use a fake.
protocol UnitSprite: AnyObject {
    var frameWidth: Int { get }
    var frameHeight: Int { get }
    var frameCount: Int { get }
    var loop: Bool { get set }
    func update()
    @discardableResult func setAnimation(anim: Int) -> Bool
    func play()
    func stop()
    func isAnimationDone() -> Bool
    func setFrame(_ frame: Int)
    func draw(video: Video, x: Int, y: Int)
}

extension Sprite: UnitSprite {}

/// Draws a unit. The unit's screen position (`x`, `y`) is the middle of its feet.
final class UnitView {

    enum Constants {
        /// Width of the health bar drawn above a selected unit.
        static let healthBarWidth = 20
        /// Vertical offset of the health bar from the top of the sprite.
        static let healthBarY = -3
        /// The size used for hit-tests when the unit has no sprite.
        static let defaultSize = (width: 20, height: 30)
    }

    /// The first animation of each pack in a soldier sprite. Each pack has one animation
    /// per direction (8), in the order of `res.json`'s animpaks.
    enum AnimationPack: Int {
        case idle = 0
        case walking = 8
        case dying = 16
        case attacking = 24

        /// The pack shown in each unit state, as in the original.
        init(_ state: Unit.State) {
            switch state {
            case .idle, .healing: self = .idle
            case .moving, .pursuingUnit, .patrolling: self = .walking
            case .dying, .dead: self = .dying
            case .attacking: self = .attacking
            }
        }
    }

    private let sprite: (any UnitSprite)?
    /// The state the animation was last chosen for.
    private var shownState: Unit.State?

    init(sprite: (any UnitSprite)?) {
        self.sprite = sprite
    }

    /// The size of the current frame.
    var size: (width: Int, height: Int) {
        guard let sprite else { return Constants.defaultSize }
        return (sprite.frameWidth, sprite.frameHeight)
    }

    // MARK: - Animation

    /// Shows the animation for the unit's state and direction (0 = north, clockwise),
    /// then advances it by one frame. Called once per frame.
    ///
    /// The dying animation plays once and then stays on its last frame.
    func update(state: Unit.State, direction: Int) {
        let animation = AnimationPack(state).rawValue + direction
        if AnimationPack(state) == .dying {
            if shownState.map(AnimationPack.init) != .dying {
                sprite?.setAnimation(anim: animation)
                sprite?.loop = false
                sprite?.play()
            }
            if let sprite, sprite.isAnimationDone() {
                sprite.setFrame(sprite.frameCount - 1)
                sprite.stop()
            }
        } else {
            sprite?.setAnimation(anim: animation)
            sprite?.play()
        }
        shownState = state
        sprite?.update()
    }

    // MARK: - Drawing

    /// Draws the sprite at the unit's position, with the health bar above it when `health`
    /// (the fraction of health left) is given.
    func draw(_ video: Video, x: Int, y: Int, health: Double?) {
        if let health {
            let barWidth = Int(Double(Constants.healthBarWidth) * health)
            let barY = y - (sprite?.frameHeight ?? 0) + Constants.healthBarY
            video.color = GameColor.green
            video.fillRect(x - Constants.healthBarWidth / 2, barY, barWidth, 3)
            video.color = GameColor.red
            video.fillRect(x - Constants.healthBarWidth / 2 + barWidth, barY,
                           Constants.healthBarWidth - barWidth, 3)
        }
        sprite?.draw(video: video, x: x - (sprite?.frameWidth ?? 0) / 2,
                     y: y - (sprite?.frameHeight ?? 0))
    }

    // MARK: - Hit-tests

    /// Whether the screen point (px, py) is on the sprite of a unit at (x, y).
    func contains(px: Int, py: Int, x: Int, y: Int) -> Bool {
        let (w, h) = size
        return px >= x - w / 2 && px <= x + w / 2 && py >= y - h && py <= y
    }

    /// Whether a drag rectangle covers a unit at (x, y): the sprite's full width, and its
    /// height from the middle down to the feet. Matches the original C# check, translated
    /// from its top-left convention to the unit's centre and feet.
    func isCovered(byRectX rectX: Int, y rectY: Int, w: Int, h: Int, x: Int, y: Int) -> Bool {
        let (fw, fh) = size
        return rectX <= x - fw / 2
            && rectY <= y - fh / 2
            && rectX + w > x + fw / 2
            && rectY + h > y
    }
}
