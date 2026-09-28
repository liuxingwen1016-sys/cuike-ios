import Foundation
import Vision
import UIKit
import VisionKit
import SwiftUI

enum OCRError: LocalizedError {
    case invalidImage, empty, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "这张图片暂时无法读取，请换一张照片。"
        case .empty: return "没有识别到有效文字。请换个角度或手动填写。"
        case .unavailable: return "当前设备无法使用实时扫描，可以选取图片或手动填写。"
        }
    }
}

enum OCRService {
    static func recognize(data: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let supported = try request.supportedRecognitionLanguages()
            request.recognitionLanguages = ["zh-Hans", "en-US"].filter { supported.contains($0) }
            // Image-data initializer reads EXIF orientation; no upload or remote service.
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw OCRError.empty }
            return text
        }.value
    }
}

struct LiveScannerView: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var failure: String?
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> ScannerHost {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate,
            recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        let host = ScannerHost(scanner: scanner)
        host.onError = { failure = $0 }
        return host
    }
    func updateUIViewController(_ uiViewController: ScannerHost, context: Context) { context.coordinator.parent = self }
    static func dismantleUIViewController(_ uiViewController: ScannerHost, coordinator: Coordinator) { uiViewController.scanner.stopScanning() }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: LiveScannerView
        init(parent: LiveScannerView) { self.parent = parent }
        private func read(_ items: [RecognizedItem]) {
            parent.text = items.compactMap { item in if case .text(let value) = item { return value.transcript }; return nil }.joined(separator: "\n")
        }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { read(allItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { read(allItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) { read(allItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            parent.failure = OCRError.unavailable.localizedDescription
        }
    }
}

final class ScannerHost: UIViewController {
    let scanner: DataScannerViewController
    var onError: ((String) -> Void)?
    init(scanner: DataScannerViewController) { self.scanner = scanner; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        view.addSubview(scanner.view)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scanner.didMove(toParent: self)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do { try scanner.startScanning() } catch { onError?(error.localizedDescription) }
    }
    override func viewWillDisappear(_ animated: Bool) { scanner.stopScanning(); super.viewWillDisappear(animated) }
}
