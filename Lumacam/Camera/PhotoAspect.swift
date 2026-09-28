import CoreGraphics
import Foundation
import ImageIO

enum PhotoAspect: String, CaseIterable {
    case sixteenNine = "16:9"
    case fourThree = "4:3"
    case square = "1:1"

    var title: String { rawValue }

    /// Long side divided by short side.
    var longToShortRatio: CGFloat {
        switch self {
        case .sixteenNine: 16.0 / 9.0
        case .fourThree: 4.0 / 3.0
        case .square: 1
        }
    }

    var next: PhotoAspect {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

enum PhotoCropper {
    /// Center-crops encoded photo data to `aspect`, keeping the file format and metadata.
    /// The sensor delivers 4:3 pixels with an orientation tag, so cropping by long and short side
    /// works for both portrait and landscape shots. Returns the input unchanged if it already matches.
    static func crop(_ data: Data, to aspect: PhotoAspect) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard let rect = cropRect(width: width, height: height, ratio: aspect.longToShortRatio) else { return data }
        guard let cropped = image.cropping(to: rect) else { return nil }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = cropped.width
            exif[kCGImagePropertyExifPixelYDimension] = cropped.height
            properties[kCGImagePropertyExifDictionary] = exif
        }
        properties[kCGImageDestinationLossyCompressionQuality] = 0.9

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cropped, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Returns nil when the image already has the requested ratio.
    static func cropRect(width: CGFloat, height: CGFloat, ratio: CGFloat) -> CGRect? {
        let long = max(width, height)
        let short = min(width, height)
        guard short > 0, abs(long / short - ratio) > 0.01 else { return nil }

        var newLong = long
        var newShort = short
        if long / short < ratio {
            newShort = (long / ratio).rounded(.down)
        } else {
            newLong = (short * ratio).rounded(.down)
        }
        let cropWidth = width >= height ? newLong : newShort
        let cropHeight = width >= height ? newShort : newLong
        return CGRect(
            x: ((width - cropWidth) / 2).rounded(.down),
            y: ((height - cropHeight) / 2).rounded(.down),
            width: cropWidth,
            height: cropHeight
        )
    }
}
