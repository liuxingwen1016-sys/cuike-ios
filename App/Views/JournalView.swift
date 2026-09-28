import SwiftUI
import Charts

struct JournalView: View {
    let store: BrewStore
    private var recent: [HistoryItem] { Array(store.history.prefix(7).reversed()) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("记录风味，也记录每一次微小的进步。").font(.subheadline).foregroundStyle(.secondary)
                if store.history.isEmpty {
                    EmptyCard(title: "等待第一杯的故事", detail: "完成冲煮并留下评分，你的风味旅程就从这里开始。", symbol: "book.closed")
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Metric(value: "\(store.history.count)", label: "杯已记录")
                            Metric(value: store.average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", label: "平均满意度")
                        }
                        SectionHeading(title: "最近 \(recent.count) 杯", subtitle: "主观评分 / 5")
                        Chart(Array(recent.enumerated()), id: \.element.id) { index, item in
                            LineMark(x: .value("杯次", index + 1), y: .value("评分", item.tasting.rating))
                                .foregroundStyle(Palette.accent).interpolationMethod(.linear)
                            PointMark(x: .value("杯次", index + 1), y: .value("评分", item.tasting.rating))
                                .foregroundStyle(Palette.accent)
                        }
                        .chartYScale(domain: 1...5).chartXAxis(.hidden).frame(height: 120)
                        .accessibilityLabel("最近\(recent.count)杯评分，从旧到新：\(recent.map { String($0.tasting.rating) }.joined(separator: "、"))")
                    }.padding(22).cardSurface()
                    SectionHeading(title: "每杯都有迹可循")
                    ForEach(store.history) { item in
                        NavigationLink { HistoryDetailView(store: store, id: item.id) } label: { HistoryRow(item: item) }.buttonStyle(.plain)
                    }
                }
            }.padding(24)
        }.cuikePage().navigationTitle("风味手记")
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(Palette.bean(item.session.bean.color))
                .frame(width: 44, height: 44).background(Palette.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 9) {
                Text(item.session.bean.name).font(.headline)
                Text(item.tasting.tags.isEmpty ? "尚未选择风味标签" : item.tasting.tags.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(item.session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Label("\(item.tasting.rating)", systemImage: "star.fill").font(.subheadline.bold()).foregroundStyle(Palette.accent)
        }.padding(20).cardSurface().accessibilityElement(children: .combine)
    }
}

struct HistoryDetailView: View {
    let store: BrewStore
    let id: UUID
    @State private var edit = false
    @State private var delete = false
    @Environment(\.dismiss) private var dismiss
    private var item: HistoryItem? { store.history.first { $0.id == id } }
    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 24) {
                    Text(item.session.bean.name).font(.largeTitle.bold())
                    Text(item.session.startedAt.formatted(date: .long, time: .shortened)).foregroundStyle(.secondary)
                    HStack {
                        Metric(value: "\(item.session.recipe.dose)g", label: "咖啡粉")
                        Metric(value: "1:\(DisplayFormat.ratio(item.session.recipe.ratio))", label: "粉水比")
                        Metric(value: "\(item.session.recipe.temperature)℃", label: "水温")
                    }.padding(22).cardSurface()
                    Label("\(item.tasting.rating) / 5", systemImage: "star.fill").font(.title).foregroundStyle(Palette.accent)
                    Text("酸感 \(item.tasting.acidity) · 甜感 \(item.tasting.sweetness) · 醇厚感 \(item.tasting.body)")
                    Text(item.tasting.tags.joined(separator: " · ")).foregroundStyle(Palette.accent)
                    if !item.tasting.note.isEmpty { Text(item.tasting.note).lineSpacing(7).textSelection(.enabled) }
                    Text("实际时长 \(DisplayFormat.time(item.session.actualDuration ?? 180)) · \(reason(item.session.endReason))")
                        .font(.footnote).foregroundStyle(.secondary)
                    PrimaryButton(title: "再冲一杯") {
                        if let recipe = store.recipe(for: item.session.bean.id) {
                            AppRouter.shared.openRecipe(recipe, store: store, values: item.session.recipe)
                        } else { store.message = LibraryFailure.missingRecipe.localizedDescription }
                    }
                    Button("编辑风味记录") { edit = true }.buttonStyle(.bordered).controlSize(.large)
                    ShareLink(item: shareText(item)) { Label("分享这一杯", systemImage: "square.and.arrow.up") }
                    Button("删除这条风味记录", role: .destructive) { delete = true }
                }.padding(24)
            }
        }.cuikePage().navigationTitle("这一杯的故事").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $edit) {
            if let item { NavigationStack { TastingView(store: store, session: item.session, existing: item.tasting) { edit = false } } }
        }
        .confirmationDialog("删除后，这杯将不再计入统计。", isPresented: $delete, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) { store.deleteTasting(id: id); if store.message == nil { dismiss() } }
        }
    }
    private func reason(_ reason: EndReason?) -> String {
        switch reason { case .early: return "提前结束"; case .clockAdjusted: return "时间异常后手动结束"; default: return "完整冲煮" }
    }
    private func shareText(_ item: HistoryItem) -> String {
        "萃刻 · \(item.session.bean.name)\n\(item.session.recipe.dose)g 咖啡粉 / \(item.session.recipe.water)g 水 / \(item.session.recipe.temperature)℃\n满意度 \(item.tasting.rating)/5\n\(item.tasting.tags.joined(separator: " · "))\n\(item.tasting.note)"
    }
}
