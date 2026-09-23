import CoreGraphics
import Foundation
import ImageIO

enum Avatar: String, CaseIterable, Sendable {
    case block
    case softSpark = "soft-spark"
    case ram

    static let standard = Avatar.block

    var resourceDirectory: String { "Avatars/\(rawValue)" }
}

struct CompanionAvatar {
    let avatar: Avatar
    let catalog: AnimationCatalog
    private let strips: [CompanionAnimation: CGImage]

    init(avatar: Avatar, catalog: AnimationCatalog, strips: [CompanionAnimation: CGImage]) throws {
        for animation in CompanionAnimation.allCases {
            guard let definition = catalog.animation(for: animation) else { continue }
            guard let strip = strips[animation] else {
                throw AnimationCatalog.Failure.missingResource(definition.strip)
            }
            guard strip.width == definition.frameCount * catalog.cell.width,
                  strip.height == catalog.cell.height
            else { throw AnimationCatalog.Failure.stripSizeMismatch(definition.strip) }
        }
        self.avatar = avatar
        self.catalog = catalog
        self.strips = strips
    }

    static func bundled(_ avatar: Avatar) throws -> CompanionAvatar {
        let catalog = try AnimationCatalog.bundled(avatar)
        var strips: [CompanionAnimation: CGImage] = [:]
        for animation in CompanionAnimation.allCases {
            guard let definition = catalog.animation(for: animation) else { continue }
            strips[animation] = try loadStrip(definition.strip, in: avatar.resourceDirectory)
        }
        return try CompanionAvatar(avatar: avatar, catalog: catalog, strips: strips)
    }

    static func bundledLibrary() throws -> [Avatar: CompanionAvatar] {
        try Dictionary(uniqueKeysWithValues: Avatar.allCases.map { ($0, try bundled($0)) })
    }

    var name: String { catalog.name }

    func frame(_ index: Int, of animation: CompanionAnimation) -> CGImage? {
        guard let strip = strips[animation] else { return nil }
        let cell = catalog.cell
        return strip.cropping(to: CGRect(x: index * cell.width, y: 0, width: cell.width, height: cell.height))
    }

    private static func loadStrip(_ file: String, in directory: String) throws -> CGImage {
        let name = (file as NSString).deletingPathExtension
        let extensionName = (file as NSString).pathExtension
        guard let url = Bundle.claudey.url(forResource: name, withExtension: extensionName, subdirectory: directory) else {
            throw AnimationCatalog.Failure.missingResource(file)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw AnimationCatalog.Failure.unreadableStrip(file) }
        return image
    }
}

final class AvatarPreferenceStore {
    private static let key = "avatar"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var avatar: Avatar {
        get { defaults.string(forKey: Self.key).flatMap(Avatar.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Self.key) }
    }
}
