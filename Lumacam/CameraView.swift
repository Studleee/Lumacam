import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var camera = CameraManager()
    @State private var showControls: Bool = false
    @State private var shutterPressed: Bool = false
    @GestureState private var pinchScale: CGFloat = 1.0

    // Recording timer
    @State private var recordingSeconds: Int = 0
    @State private var recordingTimer: Timer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .updating($pinchScale) { value, state, _ in state = value }
                        .onChanged { value in
                            camera.setZoomFactor(camera.zoomFactor * value / pinchScale)
                        }
                )

            VStack {
                topBar
                Spacer()
                bottomControls
            }

            if let image = camera.capturedImage {
                photoPreviewOverlay(image: image)
            }
        }
        .onAppear { camera.configure() }
        .preferredColorScheme(.dark)
        .onChange(of: camera.isRecording) { recording in
            if recording {
                recordingSeconds = 0
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    recordingSeconds += 1
                }
            } else {
                recordingTimer?.invalidate()
                recordingTimer = nil
                recordingSeconds = 0
            }
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack {
            Button(action: { camera.toggleTorch() }) {
                ZStack {
                    Circle()
                        .fill(camera.isTorchOn ? Color(hex: "FFD60A") : Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: camera.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(camera.isTorchOn ? .black : .white)
                }
            }

            Spacer()

            // Recording timer or zoom badge
            if camera.isRecording {
                recordingBadge
            } else {
                Text(String(format: "%.1fx", camera.zoomFactor))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            Button(action: { camera.switchCamera() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    var recordingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(formattedTime(recordingSeconds))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
    }

    func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Bottom Controls

    var bottomControls: some View {
        VStack(spacing: 0) {
            if showControls {
                slidersPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            modePicker
                .padding(.bottom, 16)

            HStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.4))
                    )

                Spacer()

                shutterButton

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showControls.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(showControls ? Color(hex: "FFD60A") : Color.white.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(showControls ? .black : .white)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Shutter Button

    var shutterButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { shutterPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.08)) { shutterPressed = false }
            }
            if camera.currentMode == .photo {
                camera.takePhoto()
            } else {
                camera.toggleVideoRecording()
            }
        }) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 76, height: 76)

                if camera.currentMode == .video && camera.isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(camera.currentMode == .video ? Color.red : Color(hex: "FFD60A"))
                        .frame(width: 60, height: 60)
                }
            }
            .scaleEffect(shutterPressed ? 0.88 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Mode Picker

    var modePicker: some View {
        HStack(spacing: 28) {
            ForEach([CameraManager.CaptureMode.photo, .video], id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        camera.currentMode = mode
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(mode == .photo ? "PHOTO" : "VIDEO")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(camera.currentMode == mode ? Color(hex: "FFD60A") : .white.opacity(0.45))

                        Capsule()
                            .fill(camera.currentMode == mode ? Color(hex: "FFD60A") : Color.clear)
                            .frame(width: 20, height: 2)
                    }
                }
            }
        }
    }

    // MARK: - Sliders Panel

    var slidersPanel: some View {
        VStack(spacing: 14) {
            sliderRow(
                icon: "bolt.fill",
                color: Color(hex: "FFD60A"),
                label: "FLASH",
                value: Binding(
                    get: { Double(camera.torchLevel) },
                    set: { camera.setTorchLevel(level: Float($0)) }
                ),
                range: 0.01...1.0,
                displayValue: "\(Int(camera.torchLevel * 100))%"
            )

            sliderRow(
                icon: "magnifyingglass",
                color: .white,
                label: "ZOOM",
                value: Binding(
                    get: { Double(camera.zoomFactor) },
                    set: { camera.setZoomFactor(CGFloat($0)) }
                ),
                range: 1.0...5.0,
                displayValue: String(format: "%.1fx", camera.zoomFactor)
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    func sliderRow(icon: String, color: Color, label: String, value: Binding<Double>, range: ClosedRange<Double>, displayValue: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(displayValue)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Slider(value: value, in: range)
                    .tint(color)
            }
        }
    }

    // MARK: - Photo Preview Overlay

    func photoPreviewOverlay(image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .shadow(color: .black.opacity(0.5), radius: 20)

                Spacer()

                HStack(spacing: 20) {
                    Button(action: { camera.capturedImage = nil }) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Button(action: { camera.capturedImage = nil }) {
                        Label("Done", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color(hex: "FFD60A"))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 52)
            }
        }
        .transition(.opacity)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension CameraManager.CaptureMode: Hashable {}
