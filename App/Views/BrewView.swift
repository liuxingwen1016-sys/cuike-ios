import SwiftUI
import Combine

struct BrewView: View {
    let store: BrewStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("haptics") private var haptics = true
    @State private var now = Date()
    @State private var early = false
    @State private var discard = false
    @State private var tasting = false
    @State private var feedback = 0
    @State private var previousStage: BrewStage?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            if let session = store.pending {
                VStack(spacing: 26) {
                    Text(session.bean.name).font(.title2.bold())
                    Text("给香气一点时间，也给自己。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    timer(session)
                    VStack(spacing: 12) {
                        Text(session.stage(at: now).title).font(.title2.bold())
                        Text(session.stage(at: now).instruction(recipe: session.recipe))
                            .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    HStack {
                        Metric(value: "\(session.recipe.dose)g", label: "咖啡粉")
                        Metric(value: "\(session.recipe.water)g", label: "目标水量")
                        Metric(value: "\(session.recipe.temperature)℃", label: "水温")
                    }.padding(22).cardSurface()
                    if store.clockNeedsConfirmation {
                        VStack(spacing: 16) {
                            Text("设备时间发生变化。为避免错误计时，请确认这一杯是否已经结束。")
                            Button("确认结束并记录") { if store.finish(clockAdjusted: true) { tasting = true } }
                            Button("放弃这次记录", role: .destructive) { discard = true }
                        }.padding(22).cardSurface()
                    } else if session.status == .awaiting {
                        PrimaryButton(title: "记下这一杯", symbol: "pencil.line") { tasting = true }.accessibilityIdentifier("tasteBrew")
                        Button("放弃这次记录", role: .destructive) { discard = true }
                    } else {
                        Text("冲煮会持续进行，无需一直亮着屏幕。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("提前结束") { early = true }.buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("finishEarly")
                    }
                }.padding(24)
            } else {
                EmptyCard(title: "这杯已收好", detail: "回到冲煮台，为下一杯做准备。")
                    .padding(24)
                Button("回到冲煮台") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }.cuikePage().navigationTitle("这一刻，只管冲煮").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("收起") { dismiss() } } }
        .confirmationDialog("提前结束这一杯？将保留实际时长。", isPresented: $early, titleVisibility: .visible) {
            Button("结束并记录") { if store.finish() { tasting = true } }.accessibilityIdentifier("confirmFinishEarly")
        }
        .confirmationDialog("放弃这条未完成的记录？", isPresented: $discard, titleVisibility: .visible) {
            Button("放弃记录", role: .destructive) { store.discard(); if store.pending == nil { dismiss() } }
        }
        .sheet(isPresented: $tasting) {
            if let pending = store.pending {
                NavigationStack {
                    TastingView(store: store, session: pending) {
                        tasting = false
                        AppRouter.shared.tab = 2
                        dismiss()
                    }
                }
            }
        }
        .onAppear { now = store.effectiveNow(); previousStage = store.pending?.stage(at: now) }
        .onReceive(ticker) { _ in
            guard scenePhase == .active else { return }
            now = store.effectiveNow()
            if let stage = store.pending?.stage(at: now) {
                if previousStage != nil && stage != previousStage { feedback += 1 }
                previousStage = stage
            }
        }
        .sensoryFeedback(.success, trigger: feedback) { _, _ in haptics && scenePhase == .active }
    }

    private func timer(_ session: BrewSnapshot) -> some View {
        let remaining = session.status == .running ? session.remaining(at: now) : 0
        return ZStack {
            Circle().stroke(Palette.accent.opacity(0.10), lineWidth: 12)
            Circle().trim(from: 0, to: CGFloat(session.elapsed(at: now)) / CGFloat(session.recipe.duration))
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.4), value: remaining)
            VStack(spacing: 14) {
                Image(systemName: session.status == .running ? "drop" : "checkmark").font(.title).foregroundStyle(Palette.accent)
                Text(DisplayFormat.time(remaining)).font(.system(size: 58, weight: .light, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1).accessibilityIdentifier("brewCountdown")
                Text(session.status == .running ? "距离这一杯完成" : "慢慢品尝").font(.subheadline).foregroundStyle(.secondary)
            }.padding(24)
        }.frame(maxWidth: 290).aspectRatio(1, contentMode: .fit).padding(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.status == .running ? "剩余 \(remaining) 秒，\(session.stage(at: now).title)" : "冲煮已结束")
    }
}
