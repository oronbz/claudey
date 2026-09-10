import AppKit

final class CompanionController {
    var onClick: (() -> Void)?

    private let behavior: CompanionBehavior
    private let panel: CompanionPanel
    private let spriteView: SpriteView
    private let positions: CompanionPositionStore
    private var frameTimer: Timer?

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    init(catalog: AnimationCatalog, sheet: SpriteSheet, positions: CompanionPositionStore = CompanionPositionStore()) {
        self.positions = positions
        behavior = CompanionBehavior(catalog: catalog, startedAt: ProcessInfo.processInfo.systemUptime)

        let size = catalog.desktopSize
        panel = CompanionPanel(size: size)
        spriteView = SpriteView(catalog: catalog, sheet: sheet)
        panel.contentView = spriteView

        spriteView.onHoverChange = { [weak self] isHovering in
            guard let self else { return }
            behavior.setHovering(isHovering, at: now)
            render()
        }
        spriteView.onDrag = { [weak self] translation in
            self?.move(by: translation)
        }
        spriteView.onDragEnd = { [weak self] in
            self?.positions.savedOrigin = self?.panel.frame.origin
        }
        spriteView.onClick = { [weak self] in
            self?.onClick?()
        }

        panel.setFrameOrigin(
            CompanionPlacement.origin(saved: positions.savedOrigin, size: size, visibleFrames: visibleFrames)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
        render()
    }

    func hide() {
        frameTimer?.invalidate()
        frameTimer = nil
        behavior.setHovering(false, at: now)
        panel.orderOut(nil)
    }

    func show(_ animation: CompanionAnimation) {
        behavior.show(animation, at: now)
        render()
    }

    private func move(by translation: CGSize) {
        let origin = panel.frame.origin
        panel.setFrameOrigin(CGPoint(x: origin.x + translation.width, y: origin.y + translation.height))
    }

    private func render() {
        let presentation = behavior.presentation(at: now)
        spriteView.show(frameID: presentation.frameID)
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        frameTimer?.invalidate()
        frameTimer = nil

        guard panel.isVisible, let delay = behavior.timeUntilNextFrame(at: now) else { return }

        let timer = Timer(timeInterval: max(delay, 1.0 / 60), repeats: false) { [weak self] _ in
            self?.render()
        }
        // Dragging Claudey and opening his menu both run the event-tracking
        // run loop mode, where a default-mode timer would stall his animation.
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private var visibleFrames: [CGRect] {
        NSScreen.screens.map(\.visibleFrame)
    }

    @objc private func screenParametersChanged() {
        let origin = CompanionPlacement.origin(
            saved: panel.frame.origin,
            size: panel.frame.size,
            visibleFrames: visibleFrames
        )
        panel.setFrameOrigin(origin)
        positions.savedOrigin = origin
    }
}
