import SwiftUI
import UIKit

struct BeanLibraryView: View {
    let store: BrewStore
    @State private var search = ""
    @State private var filter = "全部"
    @State private var showArchived = false
    @State private var add = false
    private var filtered: [BeanRecord] {
        store.beans.filter {
            $0.archived == showArchived && (filter == "全部" || $0.process == filter) &&
            (search.isEmpty || "\($0.name) \($0.origin) \($0.process)".localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("好咖啡，从认识一袋豆开始。").font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["全部", "水洗", "日晒", "蜜处理", "厌氧", "未知"], id: \.self) { item in
                            Button { filter = item } label: { TagPill(title: item, selected: filter == item) }.buttonStyle(.plain)
                        }
                    }
                }
                Toggle("查看已归档", isOn: $showArchived).font(.subheadline)
                if filtered.isEmpty {
                    EmptyCard(title: "这里还没有豆档案", detail: search.isEmpty ? "添加一袋豆，或试试其他筛选。" : "换个名字或产地试试。", symbol: "leaf")
                }
                ForEach(filtered) { bean in
                    NavigationLink { BeanDetailView(store: store, bean: bean) } label: {
                        HStack(spacing: 18) {
                            BeanBag(color: bean.color).frame(width: 70, height: 100)
                            VStack(alignment: .leading, spacing: 9) {
                                Text(bean.name).font(.headline)
                                Text(bean.origin.isEmpty ? "产地未填写" : bean.origin).font(.subheadline).foregroundStyle(.secondary)
                                Text("\(bean.process) · \(bean.roast)").font(.caption).foregroundStyle(Palette.accent)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(20).cardSurface()
                    }.buttonStyle(.plain)
                }
            }.padding(24)
        }
        .cuikePage().navigationTitle("豆档案")
        .searchable(text: $search, prompt: "搜索豆名、产地")
        .toolbar { Button { add = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加咖啡豆").accessibilityIdentifier("addBean") }
        .sheet(isPresented: $add) { NavigationStack { ScanView(store: store) } }
    }
}

struct BeanDetailView: View {
    let store: BrewStore
    let bean: BeanRecord
    @State private var edit = false
    @State private var confirmArchive = false
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                BeanBag(color: bean.color).frame(width: 164, height: 220).frame(maxWidth: .infinity).padding(.vertical, 20)
                Text(bean.name).font(.largeTitle.bold())
                Text(bean.origin.isEmpty ? "产地未填写" : bean.origin).foregroundStyle(.secondary)
                HStack { TagPill(title: bean.process); TagPill(title: bean.roast) }
                if bean.isSample { Text("内置示例档案 · 参数为起点配方，可按口味调整。").font(.footnote).foregroundStyle(.secondary) }
                if bean.archived {
                    PrimaryButton(title: "恢复到正在使用", symbol: "arrow.uturn.backward") { store.setArchived(bean, false) }
                } else if let recipe = store.recipe(for: bean.id) {
                    PrimaryButton(title: "为这袋豆准备配方") { AppRouter.shared.openRecipe(recipe, store: store) }
                }
                Button("编辑档案") { edit = true }.buttonStyle(.bordered).controlSize(.large)
                if !bean.archived { Button("归档这袋豆", role: .destructive) { confirmArchive = true } }
                if store.canDelete(bean) { Button("删除这袋豆", role: .destructive) { confirmDelete = true } }
            }.padding(24)
        }.cuikePage().navigationTitle("认识这袋豆").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $edit) {
            NavigationStack {
                BeanEditorView(store: store, draft: BeanDraft(name: bean.name, origin: bean.origin,
                    process: bean.process, roast: bean.roast, color: bean.color), editing: bean.id)
            }
        }
        .confirmationDialog("归档后不能为它开始新的冲煮，历史记录会保留。", isPresented: $confirmArchive, titleVisibility: .visible) {
            Button("归档", role: .destructive) { store.setArchived(bean, true) }
        }
        .confirmationDialog("删除这袋豆和它的配方？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) { store.deleteBean(bean); if store.message == nil { dismiss() } }
        }
    }
}

struct BeanEditorView: View {
    let store: BrewStore
    @State var draft: BeanDraft
    var editing: UUID? = nil
    var rawText: String = ""
    var sourceImage: UIImage? = nil
    var onSaved: (() -> Void)? = nil
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            if let sourceImage {
                Section("识别原图") {
                    Image(uiImage: sourceImage).resizable().scaledToFit().frame(maxHeight: 220)
                        .accessibilityLabel("本次选取的咖啡豆袋照片")
                }
            }
            if !rawText.isEmpty {
                Section {
                    DisclosureGroup("查看识别原文") { Text(rawText).font(.subheadline).textSelection(.enabled) }
                    Text("请核对后保存。没有明确识别到的字段留空，不根据外观推测。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("咖啡豆档案") {
                TextField("豆名（必填，最多40字）", text: $draft.name).accessibilityIdentifier("beanName")
                TextField("产地（选填）", text: $draft.origin)
                Picker("处理法", selection: $draft.process) {
                    ForEach(["未知", "水洗", "日晒", "蜜处理", "厌氧"], id: \.self) { Text($0) }
                }
                Picker("烘焙度", selection: $draft.roast) {
                    ForEach(["未知", "浅烘焙", "浅中烘焙", "中烘焙", "深烘焙"], id: \.self) { Text($0) }
                }
                Picker("档案颜色", selection: $draft.color) {
                    Text("陶土橙").tag("terracotta"); Text("鼠尾草绿").tag("sage"); Text("可可棕").tag("cocoa")
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("beanError") } }
            Section {
                Button("保存档案") {
                    do {
                        try draft.validate()
                        if store.saveBean(draft, editing: editing) { onSaved?(); dismiss() }
                        else { error = store.message; store.message = nil }
                    } catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("saveBean")
            }
        }
        .scrollContentBackground(.hidden).cuikePage().navigationTitle(editing == nil ? "确认豆档案" : "编辑豆档案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
    }
}
