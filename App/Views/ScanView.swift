import SwiftUI
import PhotosUI
import AVFoundation
import VisionKit

struct ScanView: View {
    let store: BrewStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var rawText = ""
    @State private var editor = false
    @State private var draft = BeanDraft()
    @State private var camera = false
    @State private var scanningText = ""
    @State private var cameraFailure: String?
    @State private var error: String?
    @State private var busy = false
    @State private var processing: Task<Void, Never>?
    @State private var librarySaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("把一袋豆的故事，\n带进萃刻。").font(.largeTitle.bold())
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(Palette.ink.opacity(0.05))
                    if let image { Image(uiImage: image).resizable().scaledToFit().padding(18) }
                    else { BeanBag().frame(width: 145, height: 200) }
                    RoundedRectangle(cornerRadius: 18).stroke(Palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [12, 7])).padding(30)
                }.frame(height: 290).accessibilityLabel("咖啡豆袋图片")
                Text("扫描豆袋文字，核对后保存。所有识别都在设备上完成。").font(.subheadline).foregroundStyle(.secondary)
                if busy { ProgressView("正在识别文字…").frame(maxWidth: .infinity) }
                if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                PrimaryButton(title: "用相机扫描", symbol: "viewfinder") { Task { await openCamera() } }.disabled(busy)
                HStack(spacing: 18) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("从相册选取", systemImage: "photo") }
                    Spacer()
                    Button("使用示例图片") { readSample() }
                }.font(.subheadline).disabled(busy)
                Divider()
                Button("手动填写档案") { image = nil; rawText = ""; draft = BeanDraft(); editor = true }
                    .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("manualBean")
                Text("示例图只用于演示；点击后会执行真实文字识别，仍需你核对字段。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }.cuikePage().navigationTitle("添加咖啡豆").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { processing?.cancel(); dismiss() } } }
        .onChange(of: selectedPhoto) { _, photo in
            processing?.cancel()
            processing = Task {
                do {
                    guard let data = try await photo?.loadTransferable(type: Data.self) else { return }
                    try Task.checkCancellation()
                    await recognize(data)
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
            }
        }
        .sheet(isPresented: $editor, onDismiss: { if librarySaved { dismiss() } }) {
            NavigationStack {
                BeanEditorView(store: store, draft: draft, rawText: rawText, sourceImage: image) { librarySaved = true }
            }
        }
        .fullScreenCover(isPresented: $camera, onDismiss: {
            if !rawText.isEmpty { draft = LabelParser.parse(rawText); editor = true }
        }) {
            NavigationStack {
                VStack(spacing: 0) {
                    LiveScannerView(text: $scanningText, failure: $cameraFailure)
                    VStack(spacing: 14) {
                        if let cameraFailure { Text(cameraFailure).font(.subheadline).foregroundStyle(.red) }
                        Text(scanningText.isEmpty ? "把豆袋文字放进取景框" : scanningText).font(.caption).lineLimit(4)
                        PrimaryButton(title: "使用这些文字", symbol: "checkmark") { rawText = scanningText; image = nil; camera = false }
                            .disabled(scanningText.isEmpty || cameraFailure != nil)
                    }.padding(20).background(Palette.paper)
                }.navigationTitle("扫描豆袋").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { camera = false } } }
            }
        }
        .onDisappear { processing?.cancel() }
    }

    @MainActor private func openCamera() async {
        error = nil
        guard DataScannerViewController.isSupported else { error = OCRError.unavailable.localizedDescription; return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: .video) }
        else { granted = status == .authorized }
        guard granted else { error = "相机未授权。你可以从相册选取、使用示例图或手动填写，也可以在系统设置中开启相机权限。"; return }
        guard DataScannerViewController.isAvailable else { error = OCRError.unavailable.localizedDescription; return }
        rawText = ""; scanningText = ""; cameraFailure = nil; camera = true
    }
    private func readSample() {
        processing?.cancel()
        guard let url = Bundle.main.url(forResource: "sample-bean", withExtension: "png"), let data = try? Data(contentsOf: url) else {
            error = "示例图片缺失，请从相册选取或手动填写。"; return
        }
        processing = Task { await recognize(data) }
    }
    @MainActor private func recognize(_ data: Data) async {
        busy = true; error = nil
        defer { busy = false }
        guard let preview = UIImage(data: data) else { error = OCRError.invalidImage.localizedDescription; return }
        image = preview
        do {
            let text = try await OCRService.recognize(data: data)
            try Task.checkCancellation()
            rawText = text
            draft = LabelParser.parse(text)
            editor = true
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
