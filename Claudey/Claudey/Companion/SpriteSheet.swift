import Foundation
import CoreGraphics
import ImageIO

struct SpriteSheet {
    let image: CGImage

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    static func bundled(catalog: AnimationCatalog) throws -> SpriteSheet {
        let name = (catalog.image as NSString).deletingPathExtension
        let extensionName = (catalog.image as NSString).pathExtension
        guard let url = Bundle.claudey.url(forResource: name, withExtension: extensionName) else {
            throw AnimationCatalog.Failure.missingResource(catalog.image)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw AnimationCatalog.Failure.unreadableSpriteSheet(catalog.image)
        }
        return SpriteSheet(image: image)
    }

    func frame(_ id: Int, in catalog: AnimationCatalog) -> CGImage? {
        guard let rect = catalog.rect(forFrame: id) else { return nil }
        return image.cropping(to: rect)
    }
}
