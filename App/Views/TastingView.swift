import SwiftUI
import UIKit

struct TastingView: View {
    let store: BrewStore
    let session: BrewSnapshot
    @State private var values: TastingValues
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @AppStorage("haptics") private var haptics = true
    private let tags = ["柑橘", "莓果", "花香", "红茶", "可可", "坚果", "焦糖", "蜂蜜"]

    init(store: BrewStore, session: BrewSnapshot, existing: TastingValues? = nil, onSaved: @escaping () -> Void) {
        self.store = store
        self.session = session
        _values = State(initialValue: existing ?? TastingValues())
        self.onSaved = onSaved
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("这一杯，\n是什么味道？").font(.largeTitle.bold())
                Text("\(session.bean.name) · \(session.recipe.dose)g / \(session.recipe.water)g")
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 18) {
                    Text("满意度").font(.headline)
                    HStack(spacing: 0) {
                        ForEach(1...5, id: \.self) { rating in
                            Button { values.rating = rating } label: {
                                Image(systemName: values.rating >= rating ? "star.fill" : "star")
                                    .font(.system(size: 28)).foregroundStyle(Palette.accent).frame(minWidth: 44, minHeight: 44)
                            }.buttonStyle(.plain).accessibilityLabel("\(rating)星")
                                .accessibilityAddTraits(values.rating == rating ? .isSelected : [])
                                .accessibilityIdentifier("rating\(rating)")
                        }
                    }
                    Text(values.rating == 0 ? "请选择你的感受" : "\(values.rating) / 5").font(.caption).foregroundStyle(.secondary)
                }.padding(22).cardSurface()
                VStack(spacing: 18) {
                    flavor("酸感", value: $values.acidity)
                    flavor("甜感", value: $values.sweetness)
                    flavor("醇厚感", value: $values.body)
                }.padding(22).cardSurface()
                SectionHeading(title: "捕捉到的风味", subtitle: "可多选")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 75))], spacing: 12) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            if values.tags.contains(tag) { values.tags.removeAll { $0 == tag } }
                            else { values.tags.append(tag) }
                        } label: { TagPill(title: tag, selected: values.tags.contains(tag)) }
                            .buttonStyle(.plain).accessibilityAddTraits(values.tags.contains(tag) ? .isSelected : [])
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "留一点感受", subtitle: "\(values.note.count)/200")
                    TextField("香气、口感，或下次想做的调整…", text: $values.note, axis: .vertical)
                        .lineLimit(4...8).padding(18).cardSurface().accessibilityIdentifier("tastingNote")
                }
                if let error { Text(error).foregroundStyle(.red) }
                PrimaryButton(title: "收好这一杯", symbol: "checkmark") {
                    if store.saveTasting(sessionID: session.id, values: values) {
                        if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                        onSaved()
                        dismiss()
                    } else { error = store.message; store.message = nil }
                }.accessibilityIdentifier("saveTasting")
            }.padding(24)
        }.cuikePage().navigationTitle("风味记录").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("稍后再记") { dismiss() } } }
        .interactiveDismissDisabled(!values.note.isEmpty || values.rating > 0)
    }
    private func flavor(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text("\(value.wrappedValue) / 5").monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }), in: 1...5, step: 1)
                .accessibilityLabel(title)
        }
    }
}
