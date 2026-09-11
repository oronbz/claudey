import AppKit

final class CompanionController {
    var onClick: (() -> Void)?

    private let behavior: CompanionBehavior
    private let director: CompanionDirector
    private let panel: CompanionPanel
    private let spriteView: SpriteView
    private let positions: CompanionPositionStore
    private var frameTimer: Timer?

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    init(catalog: AnimationCatalog, sheet: SpriteSheet, positions: CompanionPositionStore = CompanionPositionStore()) {
        self.positions = positions
        behavior = CompanionBehavior(catalog: catalog, startedAt: ProcessInfo.processInfo.systemUptime)
        director = CompanionDirector(behavior: behavior)

        let size = catalog.desktopSize
        panel = CompanionPanel(size: size)
        spriteView = SpriteView(catalog: catalog, sheet: sheet)
        panel.contentView = spriteView

        spriteView.onHoverChange = { [weak self] isHovering in
            guard let self else { return }
            behavior.setHovering(isHovering, at: now)
            render()
        }
        spriteView.onMove = { [weak self] origin in
            self?.panel.setFrameOrigin(origin)
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

    func attach(_ menu: NSMenu) {
        spriteView.menu = menu
    }

    func show() {
        panel.orderFrontRegardless()
        render()
    }

    func show(_ animation: CompanionAnimation) {
        behavior.show(animation, at: now)
        render()
    }

    func apply(_ event: ActivityEvent) {
        director.apply(event, at: now)
        render()
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
