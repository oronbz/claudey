import CoreGraphics
import Foundation

enum PointerOutcome: Equatable {
    case click
    case drag
}

struct PointerInteraction {
    static let dragThreshold: CGFloat = 3

    private let start: CGPoint
    private var last: CGPoint
    private(set) var isDragging = false

    init(startingAt point: CGPoint) {
        start = point
        last = point
    }

    mutating func moved(to point: CGPoint) -> CGSize {
        defer { last = point }

        guard isDragging else {
            let offset = CGSize(width: point.x - start.x, height: point.y - start.y)
            guard hypot(offset.width, offset.height) > Self.dragThreshold else { return .zero }
            isDragging = true
            return offset
        }
        return CGSize(width: point.x - last.x, height: point.y - last.y)
    }

    mutating func ended(at point: CGPoint) -> PointerOutcome {
        _ = moved(to: point)
        return isDragging ? .drag : .click
    }
}
