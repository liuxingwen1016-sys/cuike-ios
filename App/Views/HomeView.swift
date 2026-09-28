import SwiftUI

struct HomeView: View {
    let store: BrewStore
    @State private var settings = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("BREW MOMENTS").font(.caption2.weight(.semibold)).tracking(3).foregroundStyle(Palette.accent)
                        Text("为自己，\n好好冲一杯。").font(.largeTitle.bold()).lineSpacing(5)
                    }
                    Spacer()
                    Image(systemName: "sun.max").font(.title).foregroundStyle(Palette.accent).accessibilityHidden(true)
                }
                if let pending = store.pending {
                    Button { AppRouter.shared.showBrew = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "timer").font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(pending.status == .running ? "有一杯正在冲煮" : "上一杯，等你留下风味").font(.headline)
                                Text(pending.bean.name).font(.subheadline)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }.padding(20).foregroundStyle(Palette.accent).cardSurface()
                    }.buttonStyle(.plain).accessibilityIdentifier("resumeBrew")
                }
                if let recipe = store.lastRecipe, let bean = store.bean(id: recipe.beanID), !bean.archived {
                    hero(bean, recipe: recipe)
                } else {
                    EmptyCard(title: "从一袋好豆开始", detail: "去豆档案添加咖啡豆，准备你的第一份配方。")
                    PrimaryButton(title: "打开豆档案") { AppRouter.shared.tab = 1 }
                }
                HStack {
                    Metric(value: "\(store.history.count)", label: "已记录的好时光")
                    Metric(value: store.average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", label: "平均满意度 / 5")
                    Image(systemName: "leaf").font(.title).foregroundStyle(Palette.sage)
                }.padding(22).cardSurface()
                if let latest = store.history.first {
                    SectionHeading(title: "最近一杯", subtitle: latest.session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    NavigationLink { HistoryDetailView(store: store, id: latest.id) } label: { HistoryRow(item: latest) }
                        .buttonStyle(.plain)
                }
                Text("每一份配方，都从好奇开始。")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(24)
        }
        .cuikePage().toolbar {
            ToolbarItem(placement: .topBarLeading) { Text("萃刻").font(.title3.bold()).tracking(4) }
            ToolbarItem(placement: .topBarTrailing) {
                Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("偏好设置")
            }
        }.sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
    }

    private func hero(_ bean: BeanRecord, recipe: RecipeRecord) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("上次的选择").font(.caption).foregroundStyle(.secondary)
                    Text(bean.name).font(.title.bold())
                    Text(bean.origin.isEmpty ? "产地未填写" : bean.origin).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(bean.process) · \(bean.roast)").font(.caption).foregroundStyle(Palette.accent)
                }.frame(maxWidth: .infinity, alignment: .leading)
                BeanBag(color: bean.color).frame(width: 118, height: 161)
            }
            Divider().opacity(0.5)
            HStack {
                Metric(value: "\(recipe.dose)g", label: "咖啡粉")
                Metric(value: "1:\(DisplayFormat.ratio(recipe.ratio))", label: "粉水比")
                Metric(value: "\(recipe.values.water)g", label: "目标水量")
            }
            PrimaryButton(title: "准备这一杯") { AppRouter.shared.openRecipe(recipe, store: store) }
                .accessibilityIdentifier("prepareRecipe")
        }.padding(22).cardSurface()
    }
}
