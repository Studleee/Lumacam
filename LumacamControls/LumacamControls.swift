import AppIntents
import SwiftUI
import WidgetKit

/// Buttons for Control Center, the Lock Screen, and the Action Button.
@main
struct LumacamControlsBundle: WidgetBundle {
    var body: some Widget {
        LumacamPhotoControl()
        LumacamVideoControl()
        LumacamSelfieControl()
    }
}

struct LumacamPhotoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "goodman.Lumacam.controls.photo") {
            ControlWidgetButton(action: OpenLumacamIntent(mode: .photo)) {
                Label("Lumacam", systemImage: "camera.fill")
            }
        }
        .displayName("Lumacam Photo")
        .description("Open Lumacam ready to take a photo.")
    }
}

struct LumacamVideoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "goodman.Lumacam.controls.video") {
            ControlWidgetButton(action: OpenLumacamIntent(mode: .video)) {
                Label("Lumacam Video", systemImage: "video.fill")
            }
        }
        .displayName("Lumacam Video")
        .description("Open Lumacam ready to record a video.")
    }
}

struct LumacamSelfieControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "goodman.Lumacam.controls.selfie") {
            ControlWidgetButton(action: OpenLumacamIntent(mode: .selfie)) {
                Label("Lumacam Selfie", systemImage: "person.crop.square.fill")
            }
        }
        .displayName("Lumacam Selfie")
        .description("Open Lumacam with the front camera.")
    }
}
