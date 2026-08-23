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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("餐次", selection: $mealType) {
                            ForEach(MealType.allCases) { type in Text(type.rawValue).tag(type) }
                        }
                        .pickerStyle(.segmented)

                        if photos.isEmpty {
                            photoPlaceholder
                        } else {
                            photoStrip
                        }

                        TextField("补充一句备注（可选）", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .padding()
                }

                attachmentComposer
            }
            .navigationTitle("记录饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    append(image: image)
                    showCamera = false
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPickerItems(items) }
            }
            .alert("无法保存", isPresented: .constant(errorMessage != nil)) {
                Button("好") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
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

            PhotosPicker(selection: $pickerItems, maxSelectionCount: max(0, 4 - photos.count), matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(photos.count >= 4)

            Spacer()

            Text("\(photos.count) / 4")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                do {
                    try store.saveMeal(type: mealType, note: note, imageData: photos)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 46, height: 46)
                    .background(Color.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(photos.isEmpty)
            .opacity(photos.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items.prefix(4 - photos.count) {
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
