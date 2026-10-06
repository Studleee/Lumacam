import AppIntents

/// Settings the app shares with the Lock Screen camera, which can't read the app's defaults.
@available(iOS 18, *)
struct LumacamCaptureContext: Codable, Sendable {
    var photoAspect: String
    var torchLevel: Float
    var isTorchOn: Bool
}

/// Launches the Lock Screen camera extension when the phone is locked, and the app when it's unlocked.
@available(iOS 18, *)
struct LumacamCaptureIntent: CameraCaptureIntent {
    typealias AppContext = LumacamCaptureContext

    static let title: LocalizedStringResource = "Lumacam Camera"
    static let description = IntentDescription("Opens the Lumacam camera, even from the Lock Screen.")

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickLaunchCenter.shared.pending = .photo
        return .result()
    }
}
