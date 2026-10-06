import LockedCameraCapture
import SwiftUI

/// The camera that opens from the Lock Screen without unlocking the phone.
@main
struct LumacamLockedCapture: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCameraView(session: session)
        }
    }
}
