import CoreGraphics
import Foundation

enum PointerOutcome: Equatable {
    case click
    case drag
}

struct PointerInteraction {
    static let dragThreshold: CGFloat = 3

    private let start: CGPoint
    private let grabbedOrigin: CGPoint
    private(set) var isDragging = false

    init(startingAt point: CGPoint, windowOrigin: CGPoint) {
        start = point
        grabbedOrigin = windowOrigin
    }

    /// The window origin that keeps Claudey under the pointer, measured from
    /// where he was grabbed rather than accumulated per event, so coalesced or
    /// out-of-order moves cannot make him drift away from the cursor.
    mutating func moved(to point: CGPoint) -> CGPoint? {
        let offset = CGSize(width: point.x - start.x, height: point.y - start.y)

        if !isDragging {
            guard hypot(offset.width, offset.height) > Self.dragThreshold else { return nil }
            isDragging = true
        }
        return CGPoint(x: grabbedOrigin.x + offset.width, y: grabbedOrigin.y + offset.height)
    }

    mutating func ended(at point: CGPoint) -> PointerOutcome {
        _ = moved(to: point)
        return isDragging ? .drag : .click
    }
}
