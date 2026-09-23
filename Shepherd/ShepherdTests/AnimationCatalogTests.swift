import CoreGraphics
import Foundation
import Testing
@testable import Shepherd

struct AnimationCatalogTests {
    @Test(arguments: Avatar.allCases)
    func everyBundledAvatarMatchesTheAssetContract(_ avatar: Avatar) throws {
        let catalog = try AnimationCatalog.bundled(avatar)

        #expect(catalog.version == 2)
        #expect(catalog.id == avatar.rawValue)
        #expect(!catalog.name.isEmpty)
        #expect(catalog.cell.width == 128 && catalog.cell.height == 128)
        #expect(catalog.anchor.x == 64 && catalog.anchor.y == 112)
    }

    @Test(arguments: Avatar.allCases)
    func everyBundledAvatarDefinesEveryReaction(_ avatar: Avatar) throws {
        let catalog = try AnimationCatalog.bundled(avatar)

        for animation in CompanionAnimation.allCases {
            #expect(catalog.animation(for: animation) != nil, "\(avatar) is missing \(animation.rawValue)")
        }
    }

    @Test(arguments: Avatar.allCases)
    func everyFrameOfEveryAvatarLoads(_ avatar: Avatar) throws {
        let loaded = try CompanionAvatar.bundled(avatar)

        for animation in CompanionAnimation.allCases {
            let definition = try #require(loaded.catalog.animation(for: animation))
            for index in 0..<definition.frameCount {
                let frame = try #require(loaded.frame(index, of: animation))
                #expect(frame.width == 128 && frame.height == 128)
            }
        }
    }

    @Test func avatarsHaveDistinctNames() throws {
        let names = try Avatar.allCases.map { try AnimationCatalog.bundled($0).name }

        #expect(Set(names).count == names.count)
    }

    @Test func rejectsAStripWhoseSizeDisagreesWithItsFrameCount() throws {
        let catalog = try AnimationCatalog(json: Data(Self.catalog(frameCount: 2, index: 0, durationMs: 100).utf8))
        let oneCell = try #require(
            CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        )

        #expect(throws: AnimationCatalog.Failure.stripSizeMismatch("test-idle.png")) {
            try CompanionAvatar(avatar: .block, catalog: catalog, strips: [.idle: oneCell])
        }
    }

    @Test func rejectsFrameIndicesOutsideTheStrip() throws {
        #expect(throws: AnimationCatalog.Failure.unknownFrame(animation: "idle", index: 7)) {
            try AnimationCatalog(json: Data(Self.catalog(frameCount: 2, index: 7, durationMs: 100).utf8))
        }
    }

    @Test func rejectsNonPositiveDurations() throws {
        #expect(throws: AnimationCatalog.Failure.invalidDuration(animation: "idle", durationMs: 0)) {
            try AnimationCatalog(json: Data(Self.catalog(frameCount: 1, index: 0, durationMs: 0).utf8))
        }
    }

    private static func catalog(frameCount: Int, index: Int, durationMs: Int) -> String {
        """
        {
          "version": 2, "id": "test", "name": "Test",
          "cell": {"width": 128, "height": 128},
          "anchor": {"x": 64, "y": 112},
          "animations": {
            "idle": {
              "strip": "test-idle.png", "frameCount": \(frameCount), "playback": "loop",
              "frames": [{"index": \(index), "durationMs": \(durationMs)}]
            }
          }
        }
        """
    }
}
