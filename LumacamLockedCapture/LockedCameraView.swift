import LockedCameraCapture
import SwiftUI

struct LockedCameraView: View {
    @State private var model: LockedCameraModel

    init(session: LockedCameraCaptureSession) {
        _model = State(initialValue: LockedCameraModel(session: session))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.state {
            case .starting:
                EmptyView()
            case .needsPermission:
                permissionPrompt
            case .ready:
                camera
            }
        }
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var camera: some View {
        ZStack {
            preview

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomControls
            }
        }
    }

    private var preview: some View {
        CameraPreview(
            service: model.service,
            onTap: { viewPoint, devicePoint in model.focus(viewPoint: viewPoint, devicePoint: devicePoint) },
            onPinchBegan: { model.beginPinch() },
            onPinchChanged: { scale in model.pinch(scale: scale) }
        )
        .aspectRatio(model.previewAspectRatio, contentMode: .fit)
        .overlay {
            ZStack {
                if let point = model.focusPoint {
                    FocusIndicator(point: point)
                        .id(model.focusTapCount)
                }
                Color.black
                    .opacity(model.isShutterFlashing ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: model.previewAspectRatio)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CircleIconButton(
                systemName: model.isTorchOn ? "bolt.fill" : "bolt.slash.fill",
                isActive: model.isTorchOn && model.capabilities.hasTorch,
                action: model.toggleTorch
            )
            .disabled(!model.capabilities.hasTorch)
            .opacity(model.capabilities.hasTorch ? 1 : 0.4)

            Spacer()

            Button(action: model.cyclePhotoAspect) {
                Text(model.photoAspect.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 52)
                    .padding(.vertical, 7)
                    .background(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .frame(width: 44, height: 44)
                .accessibilityLabel("Phone is locked")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            let zoomRange = model.capabilities.zoomRange
            if zoomRange.upperBound > zoomRange.lowerBound {
                ZoomDial(
                    zoom: model.zoom,
                    range: zoomRange,
                    lenses: model.capabilities.lenses,
                    onChange: { value, animated in model.setZoom(value, animated: animated) }
                )
            }

            HStack {
                lastCaptureButton

                Spacer()

                ShutterButton(mode: .photo, isRecording: false, isCountingDown: false, action: model.capture)

                Spacer()

                CircleIconButton(systemName: "arrow.triangle.2.circlepath", size: 50, action: model.switchCamera)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 20)
    }

    /// Opening the app asks the user to unlock; captures are imported into Photos once it opens.
    private var lastCaptureButton: some View {
        Button {
            Task { await model.openApp() }
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay {
                    if let image = model.lastCapture {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Lumacam")
    }

    private var permissionPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.lumaAccent)
            Text("Open Lumacam once to allow camera access.")
                .font(.headline)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
            Button {
                Task { await model.openApp() }
            } label: {
                Text("Open Lumacam")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.lumaAccent))
            }
        }
        .padding(40)
    }
}
