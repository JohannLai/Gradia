import AVFoundation
import Photos
import SwiftUI
import UIKit

struct WorkoutShareView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    @State private var backgroundImage: UIImage?
    @State private var overlayPosition = CGPoint(x: 0.68, y: 0.34)
    @State private var cameraAccess = WorkoutShareCameraAccess.checking
    @State private var cameraReady = false
    @State private var captureRequestID = 0
    @State private var showingShareSheet = false
    @State private var exportedImage: UIImage?
    @State private var isSavingPhoto = false
    @State private var didSavePhoto = false
    @State private var errorMessage: String?
    @State private var offerSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let backgroundImage {
                    editor(for: backgroundImage)
                } else {
                    liveCamera
                }
            }
            .navigationTitle("训练分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.white)
                        .accessibilityLabel("关闭训练分享")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingShareSheet, onDismiss: { exportedImage = nil }) {
            if let exportedImage {
                WorkoutActivityView(items: [exportedImage])
                    .ignoresSafeArea()
            }
        }
        .task { await prepareCamera() }
        .alert("无法继续", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            if offerSettings {
                Button("打开设置") { openSettings() }
            }
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var liveCamera: some View {
        VStack(spacing: 0) {
            ZStack {
                switch cameraAccess {
                case .authorized:
                    WorkoutShareLiveCamera(
                        captureRequestID: captureRequestID,
                        onReady: { cameraReady = $0 },
                        onImage: { image in
                            backgroundImage = image
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onError: showCameraError
                    )
                case .checking:
                    ProgressView("正在准备相机…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.06))
                case .unavailable:
                    VStack(spacing: 16) {
                        Image(systemName: "camera.slash")
                            .font(.system(size: 42, weight: .light))
                        Text("相机当前不可用")
                            .font(.headline)
                        if offerSettings {
                            Button("打开设置", action: openSettings)
                                .buttonStyle(.bordered)
                                .tint(.white)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.06))
                }

                if case .authorized = cameraAccess {
                    WorkoutShareOverlay(
                        session: session,
                        overlayPosition: overlayPosition
                    )

                    WorkoutShareOverlayDragSurface(
                        overlayPosition: $overlayPosition
                    )
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Spacer(minLength: 10)

            Button {
                captureRequestID += 1
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)
                }
            }
            .buttonStyle(WorkoutShareShutterButtonStyle())
            .disabled(cameraAccess != .authorized || !cameraReady)
            .accessibilityLabel("拍照")
            .accessibilityHint("拍下当前取景并进入训练分享编辑")
            .padding(.bottom, 18)
        }
    }

    private func editor(for image: UIImage) -> some View {
        VStack(spacing: 0) {
            WorkoutSharePreview(
                image: image,
                session: session,
                overlayPosition: $overlayPosition
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Label("拖动白色训练数据，调整到合适位置", systemImage: "hand.draw")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.top, 12)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Button {
                    Task { await saveToPhotos() }
                } label: {
                    Label(didSavePhoto ? "已保存" : "保存到相册", systemImage: didSavePhoto ? "checkmark" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutShareSecondaryButtonStyle())
                .disabled(isSavingPhoto || didSavePhoto)

                Button(action: exportAndShare) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutSharePrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private func prepareCamera() async {
        guard backgroundImage == nil else { return }
        offerSettings = false
        guard AVCaptureDevice.default(for: .video) != nil else {
            cameraAccess = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAccess = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                cameraAccess = .authorized
            } else {
                offerSettings = true
                cameraAccess = .unavailable
            }
        case .denied, .restricted:
            offerSettings = true
            cameraAccess = .unavailable
        @unknown default:
            cameraAccess = .unavailable
        }
    }

    private func showCameraError(_ message: String) {
        offerSettings = false
        errorMessage = message
        cameraReady = false
    }

    @MainActor
    private func composedImage() -> UIImage? {
        guard let backgroundImage else { return nil }
        return WorkoutShareRenderer.render(
            image: backgroundImage,
            session: session,
            overlayPosition: overlayPosition
        )
    }

    private func saveToPhotos() async {
        guard let image = composedImage() else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.96) else {
            errorMessage = "合成图片失败，请重试一次。"
            return
        }
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        do {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                offerSettings = true
                errorMessage = "需要允许添加照片，才能把训练分享图保存到系统相册。"
                return
            }
            try await WorkoutSharePhotoSaver.save(imageData)
            didSavePhoto = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            offerSettings = false
            errorMessage = "保存到相册失败，请稍后再试。"
        }
    }

    @MainActor
    private func exportAndShare() {
        guard let image = composedImage() else {
            offerSettings = false
            errorMessage = "合成图片失败，请重试一次。"
            return
        }

        exportedImage = image
        showingShareSheet = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct WorkoutSharePreview: View {
    let image: UIImage
    let session: WorkoutSession
    @Binding var overlayPosition: CGPoint

    var body: some View {
        GeometryReader { geometry in
            WorkoutShareArtwork(
                image: image,
                session: session,
                overlayPosition: overlayPosition
            )

            WorkoutShareOverlayDragSurface(
                overlayPosition: $overlayPosition
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("训练分享预览，白色训练数据可拖动调整位置")
    }
}

private struct WorkoutShareOverlayDragSurface: View {
    @Binding var overlayPosition: CGPoint
    @State private var dragOrigin: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            Color.white.opacity(0.001)
                .frame(width: min(geometry.size.width * 0.72, 280), height: 250)
                .contentShape(Rectangle())
                .position(
                    x: geometry.size.width * overlayPosition.x,
                    y: geometry.size.height * overlayPosition.y
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragOrigin == nil { dragOrigin = overlayPosition }
                            guard let dragOrigin else { return }
                            overlayPosition = WorkoutShareOverlayPosition.moved(
                                from: dragOrigin,
                                translation: value.translation,
                                canvasSize: geometry.size
                            )
                        }
                        .onEnded { _ in dragOrigin = nil }
                )
                .accessibilityLabel("训练数据位置")
                .accessibilityHint("拖动可调整白色训练数据的位置")
        }
    }
}

enum WorkoutShareOverlayPosition {
    static let horizontalRange: ClosedRange<CGFloat> = 0.25...0.75
    static let verticalRange: ClosedRange<CGFloat> = 0.18...0.82

    static func moved(
        from origin: CGPoint,
        translation: CGSize,
        canvasSize: CGSize
    ) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return origin }
        return CGPoint(
            x: clamp(origin.x + translation.width / canvasSize.width, to: horizontalRange),
            y: clamp(origin.y + translation.height / canvasSize.height, to: verticalRange)
        )
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct WorkoutShareArtwork: View {
    let image: UIImage
    let session: WorkoutSession
    let overlayPosition: CGPoint

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                WorkoutShareOverlay(
                    session: session,
                    overlayPosition: overlayPosition
                )
            }
        }
        .background(Color.black)
        .clipped()
    }
}

private struct WorkoutShareOverlay: View {
    let session: WorkoutSession
    let overlayPosition: CGPoint

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        .black.opacity(0.24),
                        .clear,
                        .clear,
                        .black.opacity(0.34)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                WorkoutShareMetrics(
                    session: session,
                    scale: geometry.size.width / WorkoutShareRenderer.previewBaselineWidth
                )
                .frame(width: geometry.size.width * 0.64)
                .position(
                    x: geometry.size.width * overlayPosition.x,
                    y: geometry.size.height * overlayPosition.y
                )

                VStack {
                    Spacer()
                    HStack {
                        Text("GRADIA")
                            .font(.system(size: geometry.size.width * 0.027, weight: .black, design: .rounded))
                            .tracking(geometry.size.width * 0.008)
                        Spacer()
                        Text(session.date.formatted(.dateTime.year().month().day()))
                            .font(.system(size: geometry.size.width * 0.023, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.45), radius: 5, y: 2)
                    .padding(geometry.size.width * 0.045)
                }
            }
        }
    }
}

private struct WorkoutShareMetrics: View {
    let session: WorkoutSession
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("训练完成")
                .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                .tracking(2.6 * scale)
                .padding(.bottom, 5 * scale)

            Text(WorkoutShareCopy.title(for: session))
                .font(.system(size: 26 * scale, weight: .bold, design: .rounded))
                .padding(.bottom, 22 * scale)

            workoutStat(label: "用时", value: "\(session.durationMinutes) 分钟")
            workoutStat(label: "工作组", value: "\(session.completedSetCount) 组")
            workoutStat(label: "训练容量", value: "\(formattedVolume) kg", isLast: true)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.72), radius: 7 * scale, x: 0, y: 2 * scale)
        .padding(10 * scale)
    }

    private var formattedVolume: String {
        session.totalVolume.formatted(
            .number.precision(.fractionLength(0)).grouping(.automatic)
        )
    }

    private func workoutStat(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                .opacity(0.88)
            Text(value)
                .font(.system(size: 34 * scale, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .padding(.bottom, isLast ? 0 : 15 * scale)
    }
}

enum WorkoutShareCopy {
    static func title(for session: WorkoutSession) -> String {
        session.planDay.focus
    }
}

enum WorkoutSharePhotoSaver {
    nonisolated static func save(_ imageData: Data) async throws {
        let changes: @Sendable () -> Void = {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: WorkoutSharePhotoSaveError.unknown)
                }
            }
        }
    }
}

enum WorkoutSharePhotoSaveError: Error {
    case unknown
}

@MainActor
enum WorkoutShareRenderer {
    static let outputSize = CGSize(width: 1080, height: 1440)
    static let previewBaselineWidth: CGFloat = 390

    static func render(
        image: UIImage,
        session: WorkoutSession,
        overlayPosition: CGPoint
    ) -> UIImage? {
        let artwork = WorkoutShareArtwork(
            image: image,
            session: session,
            overlayPosition: overlayPosition
        )
        .frame(width: outputSize.width, height: outputSize.height)

        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

private enum WorkoutShareCameraAccess {
    case checking
    case authorized
    case unavailable
}

private struct WorkoutShareLiveCamera: UIViewRepresentable {
    let captureRequestID: Int
    let onReady: (Bool) -> Void
    let onImage: (UIImage) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onImage: onImage, onError: onError)
    }

    func makeUIView(context: Context) -> WorkoutShareCameraPreviewView {
        let view = WorkoutShareCameraPreviewView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: WorkoutShareCameraPreviewView, context: Context) {
        context.coordinator.captureIfRequested(captureRequestID)
    }

    static func dismantleUIView(_ uiView: WorkoutShareCameraPreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
        private let session = AVCaptureSession()
        private let photoOutput = AVCapturePhotoOutput()
        private let sessionQueue = DispatchQueue(label: "com.lizhihang.gradia.share-camera")
        private let onReady: (Bool) -> Void
        private let onImage: (UIImage) -> Void
        private let onError: (String) -> Void
        private var isConfigured = false
        private var lastCaptureRequestID = 0

        init(
            onReady: @escaping (Bool) -> Void,
            onImage: @escaping (UIImage) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onReady = onReady
            self.onImage = onImage
            self.onError = onError
        }

        @MainActor
        func attach(to view: WorkoutShareCameraPreviewView) {
            view.previewLayer.session = session
            sessionQueue.async { [weak self] in self?.configureAndStart() }
        }

        func captureIfRequested(_ requestID: Int) {
            guard requestID > lastCaptureRequestID else { return }
            lastCaptureRequestID = requestID
            sessionQueue.async { [weak self] in self?.capturePhoto() }
        }

        func stop() {
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else { return }
                self.session.stopRunning()
            }
        }

        private func configureAndStart() {
            guard !isConfigured else { return }
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                reportError("当前设备没有可用的后置相机。")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                session.beginConfiguration()
                session.sessionPreset = .photo
                guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                    session.commitConfiguration()
                    reportError("相机暂时无法启动，请稍后重试。")
                    return
                }
                session.addInput(input)
                session.addOutput(photoOutput)
                session.commitConfiguration()
                isConfigured = true
                session.startRunning()
                DispatchQueue.main.async { [onReady] in onReady(true) }
            } catch {
                reportError("相机暂时无法启动，请稍后重试。")
            }
        }

        private func capturePhoto() {
            guard isConfigured, session.isRunning else { return }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            if let connection = photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                reportError("照片拍摄失败，请重试一次。")
                return
            }
            DispatchQueue.main.async { [onImage] in onImage(image) }
        }

        private func reportError(_ message: String) {
            DispatchQueue.main.async { [onError] in onError(message) }
        }
    }
}

private final class WorkoutShareCameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

private struct WorkoutActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct WorkoutSharePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background(Color.white.opacity(configuration.isPressed ? 0.76 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct WorkoutShareSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
    }
}

private struct WorkoutShareShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.3), value: configuration.isPressed)
    }
}
