import CoreGraphics
import Foundation

enum CompanionPlacement {
    static let margin: CGFloat = 24

    static func origin(saved: CGPoint?, size: CGSize, visibleFrames: [CGRect]) -> CGPoint {
        guard let primary = visibleFrames.first else { return saved ?? .zero }

        guard let saved else {
            return CGPoint(x: primary.maxX - size.width - margin, y: primary.minY + margin)
        }

        let rect = CGRect(origin: saved, size: size)
        if visibleFrames.contains(where: { $0.contains(rect) }) { return saved }

        let host = visibleFrames
            .map { (frame: $0, overlap: overlap($0, rect)) }
            .filter { $0.overlap > 0 }
            .max { $0.overlap < $1.overlap }?
            .frame ?? primary

        return clamp(rect, into: host)
    }

    private static func overlap(_ frame: CGRect, _ rect: CGRect) -> CGFloat {
        let intersection = frame.intersection(rect)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func clamp(_ rect: CGRect, into frame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(rect.minX, frame.minX), frame.maxX - rect.width),
            y: min(max(rect.minY, frame.minY), frame.maxY - rect.height)
        )
    }
}

final class CompanionPositionStore {
    private static let key = "companionOrigin"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedOrigin: CGPoint? {
        get {
            guard let stored = defaults.array(forKey: Self.key) as? [Double], stored.count == 2 else {
                return nil
            }
            return CGPoint(x: stored[0], y: stored[1])
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Self.key)
                return
            }
            defaults.set([Double(newValue.x), Double(newValue.y)], forKey: Self.key)
        }
    }
}
