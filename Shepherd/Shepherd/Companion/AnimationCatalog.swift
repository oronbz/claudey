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
    struct Cell: Decodable, Sendable {
        let width: Int
        let height: Int

        var size: CGSize { CGSize(width: width, height: height) }
    }

    struct Anchor: Decodable, Sendable {
        let x: Int
        let y: Int
    }

    struct Step: Decodable, Sendable {
        let index: Int
        let durationMs: Int
    }

    struct Animation: Decodable, Sendable {
        let strip: String
        let frameCount: Int
        let playback: AnimationPlayback
        let steps: [Step]

        private enum CodingKeys: String, CodingKey {
            case strip, frameCount, playback
            case steps = "frames"
        }
    }

    enum Failure: Error, Equatable {
        case missingResource(String)
        case emptyAnimation(String)
        case unknownFrame(animation: String, index: Int)
        case invalidDuration(animation: String, durationMs: Int)
        case unreadableStrip(String)
        case stripSizeMismatch(String)
    }

    let version: Int
    let id: String
    let name: String
    let cell: Cell
    let anchor: Anchor
    let desktopScale: Int?
    let animations: [String: Animation]

    init(json: Data) throws {
        self = try JSONDecoder().decode(AnimationCatalog.self, from: json)
        try validate()
    }

    static func bundled(_ avatar: Avatar = .standard) throws -> AnimationCatalog {
        guard let url = Bundle.shepherd.url(
            forResource: "avatar",
            withExtension: "json",
            subdirectory: avatar.resourceDirectory
        ) else {
            throw Failure.missingResource("\(avatar.resourceDirectory)/avatar.json")
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

    private func validate() throws {
        for (name, animation) in animations {
            guard !animation.steps.isEmpty, animation.frameCount > 0 else { throw Failure.emptyAnimation(name) }
            for step in animation.steps {
                guard (0..<animation.frameCount).contains(step.index) else {
                    throw Failure.unknownFrame(animation: name, index: step.index)
                }
                guard step.durationMs > 0 else {
                    throw Failure.invalidDuration(animation: name, durationMs: step.durationMs)
                }
            }
        }
    }
}

extension Bundle {
    static var shepherd: Bundle { Bundle(for: AppDelegate.self) }
}
