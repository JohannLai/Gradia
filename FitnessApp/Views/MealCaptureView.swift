import PhotosUI
import SwiftUI
import UIKit

struct MealCaptureView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var mealType = MealCaptureView.inferredMealType()
    @State private var note = ""
    @State private var photos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var errorMessage: String?
    @State private var saveState: SaveState = .idle

    private var hasPhotos: Bool { !photos.isEmpty }
    private var canSubmit: Bool { hasPhotos && saveState == .idle }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("记录饮食")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                            .disabled(saveState != .idle)
                    }
                }
                .fullScreenCover(isPresented: $showCamera) { cameraCover }
                .onChange(of: pickerItems) { _, items in
                    Task { await loadPickerItems(items) }
                }
                .alert("无法保存", isPresented: errorAlertBinding) {
                    Button("好") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
                .sensoryFeedback(.success, trigger: saveSucceeded)
                .animation(.snappy(duration: 0.28), value: photos.count)
                .animation(.snappy(duration: 0.28), value: saveState)
        }
    }

    private var saveSucceeded: Bool { saveState == .saved }

    @ViewBuilder
    private var content: some View {
        if saveState == .saved {
            successPanel
        } else {
            captureForm
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var cameraCover: some View {
        CameraPicker { image in
            append(image: image)
            showCamera = false
        } onCancel: {
            showCamera = false
        }
        .ignoresSafeArea()
    }

    private var captureForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("餐次", selection: $mealType) {
                        ForEach(MealType.allCases) { type in Text(type.rawValue).tag(type) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(saveState == .saving)

                    if photos.isEmpty {
                        photoPlaceholder
                    } else {
                        photoStrip
                    }

                    TextField("补充一句备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(14)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
                        .disabled(saveState == .saving)
                }
                .padding()
            }

            attachmentComposer
        }
    }

    private var successPanel: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text("已记录这一餐")
                .font(.title2.weight(.semibold))
            Text("\(mealType.rawValue) · \(photos.count) 张照片已保存")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("已记录这一餐，\(mealType.rawValue)，\(photos.count) 张照片已保存")
    }

    private var photoPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.primary)
            Text("拍下这一餐即可")
                .font(.headline)
            Text("不需要手填热量；照片会进入你的私有 Google Drive，等待后续分析。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .contentCard()
    }

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            Button {
                                photos.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                    .frame(width: 28, height: 28)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var attachmentComposer: some View {
        HStack(spacing: 12) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                else { errorMessage = "当前设备没有可用相机，请从相册选择。" }
            } label: {
                Image(systemName: "camera.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(saveState == .saving)

            PhotosPicker(selection: $pickerItems, maxSelectionCount: max(0, 4 - photos.count), matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(photos.count >= 4 || saveState == .saving)

            Spacer()

            Text("\(photos.count) / 4")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            submitButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var submitButton: some View {
        Button(action: submit) {
            ZStack {
                Circle()
                    .fill(submitFill)
                if saveState == .saving {
                    ProgressView()
                        .tint(submitGlyph)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(submitGlyph)
                }
            }
            .frame(width: 46, height: 46)
            .environment(\.isEnabled, true)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .id("meal-submit-\(hasPhotos)")
        .accessibilityLabel("提交饮食记录")
        .accessibilityHint(hasPhotos ? "保存这一餐" : "先添加至少一张照片")
    }

    private var submitFill: Color {
        hasPhotos ? Color(uiColor: .label) : Color(uiColor: .tertiaryLabel).opacity(0.28)
    }

    private var submitGlyph: Color {
        hasPhotos ? Color(uiColor: .systemBackground) : Color(uiColor: .tertiaryLabel)
    }

    @MainActor
    private func submit() {
        guard canSubmit else { return }
        saveState = .saving
        do {
            try store.saveMeal(type: mealType, note: note, imageData: photos)
            saveState = .saved
            Task {
                try await Task.sleep(for: .milliseconds(1100))
                dismiss()
            }
        } catch {
            saveState = .idle
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            guard photos.count < 4 else { break }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            append(image: image)
        }
        pickerItems = []
    }

    private func append(image: UIImage) {
        guard photos.count < 4, let data = image.preparingForUpload()?.jpegData(compressionQuality: 0.8) else { return }
        photos.append(data)
    }

    private static func inferredMealType(now: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: now)
        return switch hour {
        case 5..<11: .breakfast
        case 11..<15: .lunch
        case 15..<22: .dinner
        default: .snack
        }
    }
}

private enum SaveState: Equatable {
    case idle, saving, saved
}

private struct CameraPicker: UIViewControllerRepresentable {
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
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            else { parent.onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
    }
}

private extension UIImage {
    func preparingForUpload(maxDimension: CGFloat = 1600) -> UIImage? {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }
        let ratio = maxDimension / largest
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
