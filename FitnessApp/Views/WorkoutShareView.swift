import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct WorkoutShareView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    @State private var backgroundImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var overlayPosition = CGPoint(x: 0.68, y: 0.34)
    @State private var showingCamera = false
    @State private var showingShareSheet = false
    @State private var exportedImage: UIImage?
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?
    @State private var offerSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let backgroundImage {
                    editor(for: backgroundImage)
                } else {
                    sourceChooser
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
        .fullScreenCover(isPresented: $showingCamera) {
            WorkoutShareCameraPicker { image in
                backgroundImage = image
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: { exportedImage = nil }) {
            if let exportedImage {
                WorkoutActivityView(items: [exportedImage])
                    .ignoresSafeArea()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
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

    private var sourceChooser: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }

                VStack(spacing: 18) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.white)

                    VStack(spacing: 8) {
                        Text("拍下训练后的这一刻")
                            .font(.title2.bold())
                        Text("训练数据会以白字叠在照片上\n拍完后可以自由拖动位置")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .foregroundStyle(.white)
                .padding(32)
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)

            Spacer(minLength: 28)

            VStack(spacing: 12) {
                Button(action: openCamera) {
                    Label("拍摄背景", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutSharePrimaryButtonStyle())

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("从相册选择", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutShareSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .overlay {
            if isLoadingPhoto {
                ProgressView("正在载入照片…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
            }
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
                Button(action: openCamera) {
                    VStack(spacing: 5) {
                        Image(systemName: "camera.fill")
                        Text("重拍")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutShareCompactButtonStyle())

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 5) {
                        Image(systemName: "photo.on.rectangle")
                        Text("相册")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutShareCompactButtonStyle())

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

    private func openCamera() {
        offerSettings = false
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "当前设备没有可用相机，可以从相册选择一张照片。"
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    showingCamera = true
                } else {
                    offerSettings = true
                    errorMessage = "需要相机权限才能拍摄训练分享背景。"
                }
            }
        case .denied, .restricted:
            offerSettings = true
            errorMessage = "相机权限当前不可用。你可以在系统设置中允许 Gradia 使用相机。"
        @unknown default:
            errorMessage = "暂时无法访问相机，可以从相册选择一张照片。"
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            pickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw WorkoutShareError.unreadablePhoto
            }
            backgroundImage = image
        } catch {
            offerSettings = false
            errorMessage = "这张照片无法读取，请换一张再试。"
        }
    }

    @MainActor
    private func exportAndShare() {
        guard let backgroundImage else { return }

        guard let image = WorkoutShareRenderer.render(
            image: backgroundImage,
            session: session,
            overlayPosition: overlayPosition
        ) else {
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

    @State private var dragOrigin: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            WorkoutShareArtwork(
                image: image,
                session: session,
                overlayPosition: overlayPosition
            )

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
                            overlayPosition = CGPoint(
                                x: clamped(dragOrigin.x + value.translation.width / geometry.size.width, 0.25...0.75),
                                y: clamped(dragOrigin.y + value.translation.height / geometry.size.height, 0.18...0.82)
                            )
                        }
                        .onEnded { _ in dragOrigin = nil }
                )
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("训练分享预览，白色训练数据可拖动调整位置")
    }

    private func clamped(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
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
        .background(Color.black)
        .clipped()
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

            Text("\(session.planDay.rawValue) 日 · \(session.planDay.focus)")
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

private struct WorkoutShareCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: WorkoutShareCameraPicker

        init(parent: WorkoutShareCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
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

private struct WorkoutShareCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(minHeight: 54)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
    }
}

private enum WorkoutShareError: Error {
    case unreadablePhoto
}
