import SwiftUI

struct CameraScreen: View {
    @State private var model = CameraViewModel()
    @State private var showsGallery = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.authorization {
            case .unknown:
                EmptyView()
            case .denied:
                PermissionView()
            case .authorized:
                camera
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.gallery.reload() }
            }
        }
        .fullScreenCover(isPresented: $showsGallery) {
            GalleryView(store: model.gallery)
        }
        .alert("Something went wrong", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var camera: some View {
        ZStack {
            preview

            VStack(spacing: 0) {
                TopBar(model: model)
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
        .aspectRatio(model.mode == .photo ? 3.0 / 4.0 : 9.0 / 16.0, contentMode: .fit)
        .overlay {
            ZStack {
                if model.showsGrid {
                    GridOverlay()
                    LevelIndicator(level: model.level)
                }
                if let point = model.focusPoint {
                    FocusIndicator(point: point)
                        .id(model.focusTapCount)
                }
                if let countdown = model.countdown {
                    CountdownOverlay(value: countdown)
                }
                Color.black
                    .opacity(model.isShutterFlashing ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: model.mode)
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if model.showsAdjustments {
                AdjustmentsPanel(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            let zoomRange = model.capabilities.zoomRange
            if zoomRange.upperBound > zoomRange.lowerBound {
                ZoomDial(
                    zoom: model.zoom,
                    range: zoomRange,
                    lenses: model.capabilities.lenses,
                    onChange: { value, animated in model.setZoom(value, animated: animated) }
                )
            }

            ModePicker(selection: model.mode, onSelect: model.setMode)
                .disabled(model.isBusy)
                .opacity(model.isBusy ? 0.4 : 1)

            HStack {
                GalleryButton(thumbnail: model.gallery.latestThumbnail) {
                    showsGallery = true
                }
                .disabled(model.isBusy)

                Spacer()

                ShutterButton(
                    mode: model.mode,
                    isRecording: model.isRecording,
                    isCountingDown: model.countdown != nil,
                    action: model.shutterTapped
                )

                Spacer()

                CircleIconButton(systemName: "arrow.triangle.2.circlepath", size: 50, action: model.switchCamera)
                    .disabled(model.isBusy)
                    .opacity(model.isBusy ? 0.4 : 1)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.showsAdjustments)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

#Preview {
    CameraScreen()
}
