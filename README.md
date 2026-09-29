# Lumacam

An iPhone camera app built around a continuous, dimmable flash. Lumacam keeps the torch on while you frame the shot, so you can see exactly how the light falls before you take the photo.

Built with SwiftUI and AVFoundation.

## Features

- **Continuous flash**: the torch comes on at launch, and a slider sets its brightness from 1% to 100%.
- **Zoom dial**: drag a ruler to zoom, flick it to coast, or tap a lens label to jump to it. The dial snaps to lenses and gives a haptic tick as you pass each one. Pinch-to-zoom works on the preview too.
- **Multi-lens support**: uses the ultra-wide, wide, and telephoto cameras on phones that have them (for example .5x, 1x, 2x, 3x) and switches between them smoothly as you zoom.
- **Aspect ratios**: take photos in 16:9 (the default), 4:3, or 1:1. The preview matches what gets saved.
- **Tap to focus**: sets focus and exposure at the spot you tap. There's also an exposure slider for ±2 EV.
- **Self-timer**: 3 or 10 seconds, with a countdown you can cancel.
- **Grid and level**: a rule-of-thirds grid and a horizon line that turns yellow when the phone is level.
- **Photo and video**: photos save as HEIC when supported, and videos record with sound. Everything saves to your photo library with the correct orientation.
- **In-app gallery**: browse your Lumacam captures, swipe through them full screen, play videos, and delete.

## Requirements

- An iPhone running iOS 17.5 or later. The Simulator has no camera, so run the app on a real device.
- Xcode 16 or later.

## Getting started

1. Clone the repo and open the project:

   ```bash
   git clone https://github.com/Studleee/Lumacam.git
   open Lumacam/Lumacam.xcodeproj
   ```

2. Select the **Lumacam** target, open **Signing & Capabilities**, and choose your own development team.
3. Connect your iPhone, select it as the run destination, and press **⌘R**.
4. On first launch, allow access to the camera. Lumacam asks for the microphone when you switch to video, and for the photo library when you save your first capture.

If Xcode says the device needs Developer Mode, turn it on in **Settings → Privacy & Security → Developer Mode** on the iPhone.

## Project structure

```
Lumacam/
├── App/            App entry point
├── Camera/         Capture session, preview, photo library, motion, and cropping
├── ViewModels/     Camera and gallery state (@Observable)
└── Views/
    ├── Controls/   Top bar, shutter, zoom dial, mode picker, adjustments panel
    ├── Overlays/   Grid, level, focus box, countdown, permission screen
    └── Gallery/    Capture grid and full-screen viewer
```

- `CameraService` owns the `AVCaptureSession` and does all session and device work on a background queue. It reports results back to the main actor.
- `CameraViewModel` holds the UI state and turns user actions into camera commands.
- `GalleryStore` remembers which photo library assets were taken with Lumacam. The photos and videos themselves stay in the user's library.

The Xcode project uses folder-synced groups, so new files in `Lumacam/` are added to the app target automatically.

## Tests

Unit tests cover the lens presets, zoom labels, level math, self-timer, and photo cropping. Run them with **⌘U** in Xcode, or from the command line:

```bash
xcodebuild test -project Lumacam.xcodeproj -scheme Lumacam \
  -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:LumacamTests
```
