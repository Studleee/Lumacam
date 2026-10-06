import AppIntents
import Observation

enum QuickLaunchMode: String, AppEnum {
    case photo, video, selfie

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Camera Mode"
    static let caseDisplayRepresentations: [QuickLaunchMode: DisplayRepresentation] = [
        .photo: DisplayRepresentation(title: "Photo", image: .init(systemName: "camera.fill")),
        .video: DisplayRepresentation(title: "Video", image: .init(systemName: "video.fill")),
        .selfie: DisplayRepresentation(title: "Selfie", image: .init(systemName: "person.crop.square.fill")),
    ]
}

/// Opens the app ready to shoot. Compiled into both the app and the controls extension;
/// `perform()` runs in the app because `openAppWhenRun` is set.
struct OpenLumacamIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Lumacam"
    static let description = IntentDescription("Opens Lumacam ready to take a photo, record a video, or take a selfie.")
    static let openAppWhenRun = true

    @Parameter(title: "Mode", default: .photo)
    var mode: QuickLaunchMode

    init() {}

    init(mode: QuickLaunchMode) {
        self.mode = mode
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickLaunchCenter.shared.pending = mode
        return .result()
    }
}

/// Hands a quick-launch request from the intent to the camera screen.
@Observable @MainActor
final class QuickLaunchCenter {
    static let shared = QuickLaunchCenter()

    var pending: QuickLaunchMode?

    func take() -> QuickLaunchMode? {
        defer { pending = nil }
        return pending
    }
}
