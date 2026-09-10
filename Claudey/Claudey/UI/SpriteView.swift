import AppKit

final class SpriteView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onDragEnd: (() -> Void)?
    var onClick: (() -> Void)?

    private let catalog: AnimationCatalog
    private let sheet: SpriteSheet
    private var frameID = 0
    private var interaction: PointerInteraction?

    init(catalog: AnimationCatalog, sheet: SpriteSheet) {
        self.catalog = catalog
        self.sheet = sheet
        super.init(frame: CGRect(origin: .zero, size: catalog.desktopSize))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SpriteView is created in code")
    }

    func show(frameID: Int) {
        guard frameID != self.frameID else { return }
        self.frameID = frameID
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let cell = sheet.frame(frameID, in: catalog)
        else { return }

        context.interpolationQuality = .none
        context.draw(cell, in: bounds)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        interaction = PointerInteraction(startingAt: NSEvent.mouseLocation, windowOrigin: window.frame.origin)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var current = interaction else { return }
        let origin = current.moved(to: NSEvent.mouseLocation)
        interaction = current
        guard let origin else { return }
        onMove?(origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard var current = interaction else { return }
        let outcome = current.ended(at: NSEvent.mouseLocation)
        interaction = nil

        switch outcome {
        case .click: onClick?()
        case .drag: onDragEnd?()
        }
    }
}
