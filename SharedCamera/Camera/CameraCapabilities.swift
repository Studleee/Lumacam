import AVFoundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case photo, video

    var id: Self { self }
    var title: String { rawValue.uppercased() }
}

/// What the active camera can do. Zoom values are "display" factors, where 1x is the main wide lens.
struct CameraCapabilities: Equatable {
    var position: AVCaptureDevice.Position = .back
    var lenses: [CGFloat] = [1]
    var zoomRange: ClosedRange<CGFloat> = 1...1
    var exposureRange: ClosedRange<Float> = 0...0
    var hasTorch = false
    var zoom: CGFloat = 1
    var exposureBias: Float = 0

    /// Lens shortcuts in the style of the system camera: ultra-wide, 1x, a 2x crop when there is
    /// no telephoto near 2x, and the telephoto itself.
    static func lensPresets(minZoom: CGFloat, maxZoom: CGFloat, telephoto: CGFloat?) -> [CGFloat] {
        var lenses: [CGFloat] = []
        if minZoom < 0.95 { lenses.append(minZoom) }
        lenses.append(1)
        if maxZoom >= 2, telephoto.map({ $0 > 2.5 }) ?? true { lenses.append(2) }
        if let telephoto, telephoto > 1 { lenses.append(telephoto) }
        return lenses
    }
}
