import SwiftUI

struct RecipeView: View {
    let store: BrewStore
    let recipe: RecipeRecord
    @State private var values: RecipeValues
    @State private var error: String?
    @AppStorage("haptics") private var haptics = true
    @Environment(\.dismiss) private var dismiss
    init(store: BrewStore, recipe: RecipeRecord, initialValues: RecipeValues? = nil) {
        self.store = store
        self.recipe = recipe
        _values = State(initialValue: initialValues ?? recipe.values)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if let bean = store.bean(id: recipe.beanID) {
                    HStack(spacing: 18) {
                        BeanBag(color: bean.color).frame(width: 75, height: 100)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(bean.name).font(.title2.bold())
                            Text("V60 · 一人份 · 3分钟").font(.subheadline).foregroundStyle(.secondary)
                            Text(bean.origin).font(.caption).foregroundStyle(Palette.accent)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 22) {
                    Stepper(value: $values.dose, in: 10...30) {
                        HStack { Text("咖啡粉"); Spacer(); Text("\(values.dose)g").font(.title2.bold()).monospacedDigit() }
                    }.accessibilityIdentifier("doseStepper")
                    Divider()
                    HStack { Text("粉水比"); Spacer(); Text("1 : \(DisplayFormat.ratio(values.ratio))").font(.title3.bold()).monospacedDigit() }
                    Slider(value: $values.ratio, in: 14...18, step: 0.5).accessibilityLabel("粉水比")
                    Stepper("水温  \(values.temperature)℃", value: $values.temperature, in: 85...96)
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("目标总水量").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(values.water)g").font(.largeTitle.bold()).foregroundStyle(Palette.accent)
                            .contentTransition(.numericText()).accessibilityIdentifier("targetWater")
                    }
                }.padding(22).cardSurface()
                SectionHeading(title: "三段，找到自己的节奏", subtitle: "03:00")
                ForEach(0..<3) { index in
                    HStack(alignment: .top, spacing: 16) {
                        Text("0\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(Palette.accent)
                            .frame(width: 40, height: 40).background(Palette.accent.opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text(["闷蒸 · 00:00—00:30", "注水 · 00:30—02:00", "滴滤 · 02:00—03:00"][index]).font(.headline)
                            Text(BrewStage(rawValue: index)!.instruction(recipe: values)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("水量为手动注水目标，不是实时测量。参数是起点配方，可按口味调整。")
                    .font(.footnote).foregroundStyle(.secondary)
                if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                if store.pending != nil {
                    PrimaryButton(title: "回到上一杯", symbol: "timer") { dismiss() }
                } else {
                    PrimaryButton(title: "开始冲煮", symbol: "play.fill") {
                        if store.start(recipe, values: values) { dismiss() }
                        else { error = store.message; store.message = nil }
                    }.accessibilityIdentifier("startBrew")
                }
            }.padding(24)
        }
        .cuikePage().navigationTitle("冲煮配方").navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: values) { _, _ in haptics }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if store.saveRecipe(recipe, values: values) { dismiss() }
                    else { error = store.message; store.message = nil }
                }
            }
        }
    }
}
