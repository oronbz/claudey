import CoreGraphics
import Foundation
import Testing
@testable import Claudey

struct AnimationCatalogTests {
    @Test func bundledCatalogMatchesTheAssetContract() throws {
        let catalog = try AnimationCatalog.bundled()

        #expect(catalog.version == 1)
        #expect(catalog.cell.width == 128 && catalog.cell.height == 128)
        #expect(catalog.frames.count == catalog.sheet.columns * catalog.sheet.rows)
        #expect(catalog.anchor.x == 64 && catalog.anchor.y == 112)
    }

    @Test func bundledCatalogDefinesEveryReaction() throws {
        let catalog = try AnimationCatalog.bundled()

        for animation in CompanionAnimation.allCases {
            #expect(catalog.animations[animation.rawValue] != nil, "missing \(animation.rawValue)")
        }
    }

    @Test func bundledSpriteSheetLoadsAtTheDeclaredSize() throws {
        let catalog = try AnimationCatalog.bundled()
        let sheet = try SpriteSheet.bundled(catalog: catalog)

        #expect(Int(sheet.pixelSize.width) == catalog.sheet.width)
        #expect(Int(sheet.pixelSize.height) == catalog.sheet.height)
    }

    @Test func rejectsFrameIdentifiersOutsideTheSheet() throws {
        let json = """
        {
          "version": 1, "image": "sprites.png",
          "sheet": {"width": 256, "height": 128, "columns": 2, "rows": 1},
          "cell": {"width": 128, "height": 128},
          "anchor": {"x": 64, "y": 112},
          "frames": [
            {"x": 0, "y": 0, "width": 128, "height": 128},
            {"x": 128, "y": 0, "width": 128, "height": 128}
          ],
          "animations": {"idle": {"playback": "loop", "frames": [{"id": 7, "durationMs": 100}]}}
        }
        """

        #expect(throws: AnimationCatalog.Failure.unknownFrame(animation: "idle", id: 7)) {
            try AnimationCatalog(json: Data(json.utf8))
        }
    }

    @Test func rejectsNonPositiveDurations() throws {
        let json = """
        {
          "version": 1, "image": "sprites.png",
          "sheet": {"width": 128, "height": 128, "columns": 1, "rows": 1},
          "cell": {"width": 128, "height": 128},
          "anchor": {"x": 64, "y": 112},
          "frames": [{"x": 0, "y": 0, "width": 128, "height": 128}],
          "animations": {"idle": {"playback": "loop", "frames": [{"id": 0, "durationMs": 0}]}}
        }
        """

        #expect(throws: AnimationCatalog.Failure.invalidDuration(animation: "idle", durationMs: 0)) {
            try AnimationCatalog(json: Data(json.utf8))
        }
    }
}
