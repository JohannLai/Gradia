import SwiftUI
import WebKit

struct ExerciseGuide: Identifiable, Hashable, Sendable {
    let planItemID: String
    let datasetID: String
    let englishName: String
    let target: String
    let imagePath: String
    let animationPath: String
    let steps: [String]

    var id: String { planItemID }

    var imageURL: URL {
        ExerciseGuideCatalog.mediaURL(path: imagePath)
    }

    var animationURL: URL {
        ExerciseGuideCatalog.mediaURL(path: animationPath)
    }
}

enum ExerciseGuideCatalog {
    static let repositoryURL = URL(string: "https://github.com/hasaneyldrm/exercises-dataset")!
    static let mediaAttributionURL = URL(string: "https://gymvisual.com/")!
    static let sourceRevision = "7455efae41b330c265e7cd4b78dfa848e7ce5ebd"

    static let all: [ExerciseGuide] = [
        guide("A-01", "0025", "barbell bench press", "胸肌", "0025-EIeI8Vf", [
            "平躺在长凳上，双脚平放在地面，肩胛骨向后下方收紧。",
            "正手握住杠铃，握距略宽于肩宽，将杠铃移到胸部上方。",
            "保持手腕稳定，将杠铃受控下降到胸部。",
            "短暂停顿后向上推起，手臂伸展但不要猛烈锁死肘部。"
        ]),
        guide("A-02", "1463", "sled 45° leg press (side view)", "股四头肌、臀肌", "1463-2Qh2J1e", [
            "调整座椅，使起始位置的膝盖约为 90 度，腰背贴稳靠垫。",
            "双脚约与肩同宽放在踏板上，膝盖方向与脚尖一致。",
            "用全脚掌推动踏板，伸展双腿但不要锁死膝盖。",
            "受控下降到腰背仍能贴住靠垫的位置，再重复动作。"
        ]),
        guide("A-03", "0198", "cable pulldown", "背阔肌", "0198-RVwzP10", [
            "固定护膝，坐直并握住横杆，握距略宽于肩宽。",
            "胸部微微抬起，核心收紧，避免大幅后仰。",
            "先下沉肩胛，再把横杆拉向上胸。",
            "在底部短暂停顿，随后受控伸直手臂回到起始位置。"
        ]),
        guide("A-04", "0603", "lever shoulder press", "三角肌", "0603-67n3r98", [
            "调整座椅，使手柄位于肩部附近，背部贴稳靠垫。",
            "握住手柄并保持手腕中立，肘部位于舒服的角度。",
            "向上推至手臂接近伸直，不要锁死肘部。",
            "受控下降；出现熟悉的肩关节深部疼痛时立即停止。"
        ]),
        guide("A-05", "0200", "cable pushdown (rope attachment)", "肱三头肌", "0200-dU605di", [
            "将绳索装在高位滑轮，身体面向器械稳定站立。",
            "肘部贴近身体两侧，上臂保持不动。",
            "伸展肘部把绳索向下压，底部可将绳端稍向外分开。",
            "受控回到前臂接近水平的位置，避免肩膀前后摆动。"
        ]),
        guide("A-06", "0175", "cable kneeling crunch", "腹肌", "0175-WW95auq", [
            "将绳索装在高位滑轮，面向器械跪下并把绳端放在头部两侧。",
            "固定髋部，先收紧腹部。",
            "让胸骨向骨盆方向卷曲，而不是只从髋部折叠。",
            "在底部短暂停顿，再受控回到腹肌仍有张力的位置。"
        ]),
        guide("B-01", "1350", "lever seated row", "上背、背阔肌", "1350-7I6LNUG", [
            "调整座椅，让胸部稳定贴住胸垫，双脚踩稳。",
            "握住手柄，保持脊柱中立和肩膀下沉。",
            "把肘部向后拉并收拢肩胛骨，避免耸肩。",
            "短暂停顿后受控伸直手臂，不让配重片撞击。"
        ]),
        guide("B-02", "1409", "barbell glute bridge", "臀肌", "1409-qKBpF7I", [
            "上背稳定支撑，双脚踩地，杠铃或器械垫位于髋部。",
            "收紧腹部和臀部，从髋部发力向上推起。",
            "顶部让躯干与大腿接近一条直线，挤压臀部约 1 秒。",
            "避免过度反弓腰，受控下降后重复。"
        ]),
        guide("B-03", "1299", "lever incline chest press", "上胸", "1299-jHAnWmT", [
            "调整座椅，使手柄位于上胸附近，背部贴稳靠垫。",
            "选择肩部最舒服的握法，肩胛骨轻轻后收。",
            "向前上方推至手臂接近伸直。",
            "受控返回；肩痛达到 3/10 或逐组加重时停止。"
        ]),
        guide("B-04", "0599", "lever seated leg curl", "腘绳肌", "0599-Zg3XY7P", [
            "调整靠背、膝部固定垫和脚踝滚垫，使机器转轴对准膝关节。",
            "大腿贴稳座垫，双手握住把手。",
            "向下后方弯曲膝盖，收紧大腿后侧。",
            "短暂停顿后缓慢伸膝回到起始位置。"
        ]),
        guide("B-05", "0602", "lever seated reverse fly", "三角肌后束", "0602-myfUsKf", [
            "调整座椅，使胸部贴住胸垫，手柄与肩部接近同高。",
            "手臂保持轻微弯曲，肩膀下沉。",
            "将手柄向两侧和后方打开，感受后束与上背收缩。",
            "只做到肩部舒服的范围，再受控返回。"
        ]),
        guide("B-06", "0165", "cable hammer curl (rope)", "肱二头肌、前臂", "0165-HPlPoQA", [
            "将绳索装在低位滑轮，掌心相对握住绳端。",
            "身体站稳，肘部固定在身体两侧。",
            "保持上臂不动，弯曲肘部把绳索拉向肩部。",
            "顶部短暂停顿，再缓慢伸肘回到起始位置。"
        ]),
        guide("C-01", "0743", "sled hack squat", "股四头肌、臀肌", "0743-Qa55kX1", [
            "肩背贴稳靠垫，双脚约与肩同宽放在平台上。",
            "解除安全锁后同时弯曲髋和膝，膝盖方向与脚尖一致。",
            "下降到腰背仍能稳定贴住靠垫的深度。",
            "用全脚掌发力站起，顶部不要锁死膝盖。"
        ]),
        guide("C-02", "0017", "assisted pull-up", "背阔肌", "0017-kiJ4Z2K", [
            "设置合适的辅助重量，安全站上或跪上辅助平台。",
            "正手握住把手，握距略宽于肩宽，手臂伸直。",
            "先下沉肩胛，再把胸部拉向把手，肘部向身体两侧下方移动。",
            "受控下降到手臂伸直；进阶时逐步减少辅助重量。"
        ]),
        guide("C-03", "0577", "lever chest press", "胸肌", "0577-T0yTjgW", [
            "调整座椅，使手柄位于胸部中段，背部贴稳靠垫。",
            "选择肩部舒服的握法和活动范围。",
            "向前推至手臂接近伸直，保持肩膀不向前耸起。",
            "受控返回；出现肩部深层疼痛时立即停止。"
        ]),
        guide("C-04", "0594", "lever seated calf raise", "小腿", "0594-bOOdeyc", [
            "前脚掌踩稳踏板，让脚跟可以自由上下移动。",
            "先缓慢下放脚跟，在底部感受小腿拉伸。",
            "用前脚掌发力把脚跟抬到最高，顶部主动收缩。",
            "避免弹震借力，全程保持受控。"
        ]),
        guide("C-05", "0592", "lever preacher curl", "肱二头肌", "0592-b6hQYMb", [
            "调整座椅，使上臂完整贴住牧师凳垫。",
            "反手握住手柄，手腕保持中立。",
            "固定上臂，弯曲肘部把手柄拉向身体。",
            "顶部收紧二头肌，再缓慢下降，避免底部猛然锁肘。"
        ]),
        guide("C-06", "0194", "cable overhead triceps extension (rope)", "肱三头肌", "0194-2IxROQ1", [
            "将绳索装在高位滑轮，背对器械稳定站立。",
            "双手把绳索置于头后，上臂靠近头部并保持稳定。",
            "伸展肘部，把绳索向前上方推至手臂接近伸直。",
            "受控弯曲肘部返回；肩部不舒服时改用下压。"
        ]),
        guide("C-07", "0872", "reverse crunch", "腹肌", "0872-nCU1Ekp", [
            "平躺并弯曲膝盖，把双腿抬起到大腿接近垂直。",
            "收紧腹部，让骨盆向胸廓方向卷起。",
            "在顶部短暂停顿，不要只靠摆腿制造惯性。",
            "缓慢放下骨盆，保持腹部张力后重复。"
        ])
    ]

    private static let byPlanItemID = Dictionary(uniqueKeysWithValues: all.map { ($0.planItemID, $0) })

    static func guide(for planItemID: String) -> ExerciseGuide? {
        byPlanItemID[planItemID]
    }

    static func mediaURL(path: String) -> URL {
        URL(string: "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/\(sourceRevision)/\(path)")!
    }

    private static func guide(
        _ planItemID: String,
        _ datasetID: String,
        _ englishName: String,
        _ target: String,
        _ mediaStem: String,
        _ steps: [String]
    ) -> ExerciseGuide {
        ExerciseGuide(
            planItemID: planItemID,
            datasetID: datasetID,
            englishName: englishName,
            target: target,
            imagePath: "images/\(mediaStem).jpg",
            animationPath: "videos/\(mediaStem).gif",
            steps: steps
        )
    }
}

struct ExerciseGuideButton: View {
    let item: WorkoutPlanItem
    let configuration: ExerciseConfiguration?
    var compact = false

    @State private var isPresented = false

    var body: some View {
        if let guide = ExerciseGuideCatalog.guide(for: item.id) {
            Button {
                isPresented = true
            } label: {
                if compact {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title3)
                        .frame(width: 34, height: 34)
                } else {
                    Label("看动作", systemImage: "play.rectangle.fill")
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityLabel("查看\(item.name)动作演示")
            .sheet(isPresented: $isPresented) {
                ExerciseGuideSheet(item: item, guide: guide, configuration: configuration)
            }
        }
    }
}

struct ExerciseGuideHeader: View {
    let item: WorkoutPlanItem
    let configuration: ExerciseConfiguration?

    @State private var isPresented = false

    var body: some View {
        if let guide = ExerciseGuideCatalog.guide(for: item.id) {
            Button {
                isPresented = true
            } label: {
                HStack(spacing: 13) {
                    ExerciseThumbnail(url: guide.imageURL)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(item.equipment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 7) {
                        Text("\(item.repMin ?? 0)–\(item.repMax ?? 0) 次")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.name)，查看动作详情")
            .accessibilityHint("打开动作演示、步骤和训练提示")
            .sheet(isPresented: $isPresented) {
                ExerciseGuideSheet(item: item, guide: guide, configuration: configuration)
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.title3.weight(.semibold))
                Text(item.equipment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ExerciseThumbnail: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else if phase.error != nil {
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .foregroundStyle(.black.opacity(0.55))
            } else {
                ProgressView()
                    .tint(.black.opacity(0.55))
            }
        }
        .frame(width: 62, height: 62)
        .background(Color.white, in: Circle())
        .clipShape(Circle())
        .overlay {
            Circle().stroke(Color.primary.opacity(0.10), lineWidth: 0.75)
        }
    }
}

private struct ExerciseGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: WorkoutPlanItem
    let guide: ExerciseGuide
    let configuration: ExerciseConfiguration?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.largeTitle.bold())
                        Text(guide.englishName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    preview

                    VStack(alignment: .leading, spacing: 12) {
                        Label(guide.target, systemImage: "figure.strengthtraining.traditional")
                            .font(.headline)
                        Label(item.equipment, systemImage: "dumbbell.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let configuration {
                            Text(muscleText(configuration))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentCard()

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "动作步骤", subtitle: "先用轻重量熟悉轨迹")
                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(AppTheme.onAccent)
                                    .frame(width: 25, height: 25)
                                    .background(Color.primary, in: Circle())
                                Text(step)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .contentCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("你的训练提示", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(item.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentCard()
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("动作指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                ProgressView()
                if reduceMotion {
                    AsyncImage(url: guide.imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            ContentUnavailableView("演示图暂时无法加载", systemImage: "wifi.slash")
                        }
                    }
                    .frame(width: 180, height: 180)
                } else {
                    RemoteExerciseAnimation(url: guide.animationURL)
                        .frame(width: 180, height: 180)
                }
            }
            .frame(height: 212)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.name)动作动态演示")

            Link(destination: ExerciseGuideCatalog.mediaAttributionURL) {
                Text("© Gym visual · 180 × 180 演示素材")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func muscleText(_ configuration: ExerciseConfiguration) -> String {
        let primary = configuration.primaryMuscles.map(\.displayName).sorted().joined(separator: "、")
        let secondary = configuration.secondaryMuscles.map(\.displayName).sorted().joined(separator: "、")
        return secondary.isEmpty ? "主要肌群：\(primary)" : "主要：\(primary) · 辅助：\(secondary)"
    }
}

private struct RemoteExerciseAnimation: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        let source = url.absoluteString
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;width:100%;height:100%;background:transparent;display:flex;align-items:center;justify-content:center}img{width:180px;height:180px;object-fit:contain}</style>
        </head><body><img src="\(source)" alt=""></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
