import CoreGraphics
import Foundation

enum CompanionAnimation: String, CaseIterable, Sendable {
    case idle
    case working
    case finished
    case needsYou = "needs-you"
    case resting
    case hover
}

enum AnimationPlayback: String, Decodable, Sendable {
    case loop
    case hold
    case once
}

struct AnimationCatalog: Decodable, Sendable {
    struct Sheet: Decodable, Sendable {
        let width: Int
        let height: Int
        let columns: Int
        let rows: Int
    }

    struct Cell: Decodable, Sendable {
        let width: Int
        let height: Int

        var size: CGSize { CGSize(width: width, height: height) }
    }

    struct Anchor: Decodable, Sendable {
        let x: Int
        let y: Int
    }

    struct Frame: Decodable, Sendable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    struct Step: Decodable, Sendable {
        let id: Int
        let durationMs: Int
    }

    struct Animation: Decodable, Sendable {
        let playback: AnimationPlayback
        let steps: [Step]

        private enum CodingKeys: String, CodingKey {
            case playback
            case steps = "frames"
        }
    }

    enum Failure: Error, Equatable {
        case missingResource(String)
        case emptyAnimation(String)
        case unknownFrame(animation: String, id: Int)
        case invalidDuration(animation: String, durationMs: Int)
        case frameOutsideSheet(index: Int)
        case unreadableSpriteSheet(String)
    }

    let version: Int
    let image: String
    let sheet: Sheet
    let cell: Cell
    let anchor: Anchor
    let desktopScale: Int?
    let frames: [Frame]
    let animations: [String: Animation]

    init(json: Data) throws {
        self = try JSONDecoder().decode(AnimationCatalog.self, from: json)
        try validate()
    }

    static func bundled() throws -> AnimationCatalog {
        guard let url = Bundle.claudey.url(forResource: "animations", withExtension: "json") else {
            throw Failure.missingResource("animations.json")
        }
        return try AnimationCatalog(json: try Data(contentsOf: url))
    }

    func animation(for companionAnimation: CompanionAnimation) -> Animation? {
        animations[companionAnimation.rawValue]
    }

    func timeline(for companionAnimation: CompanionAnimation) -> AnimationTimeline? {
        guard let animation = animation(for: companionAnimation) else { return nil }
        return AnimationTimeline(playback: animation.playback, steps: animation.steps)
    }

    var desktopSize: CGSize {
        CGSize(width: cell.width * (desktopScale ?? 1), height: cell.height * (desktopScale ?? 1))
    }

    func rect(forFrame id: Int) -> CGRect? {
        guard frames.indices.contains(id) else { return nil }
        let frame = frames[id]
        return CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
    }

    private func validate() throws {
        let bounds = CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height)
        for (index, frame) in frames.enumerated() {
            let rect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
            guard bounds.contains(rect) else { throw Failure.frameOutsideSheet(index: index) }
        }

        for (name, animation) in animations {
            guard !animation.steps.isEmpty else { throw Failure.emptyAnimation(name) }
            for step in animation.steps {
                guard frames.indices.contains(step.id) else {
                    throw Failure.unknownFrame(animation: name, id: step.id)
                }
                guard step.durationMs > 0 else {
                    throw Failure.invalidDuration(animation: name, durationMs: step.durationMs)
                }
            }
        }
    }
}

extension Bundle {
    static var claudey: Bundle { Bundle(for: AppDelegate.self) }
}
