import SwiftUI
import WidgetKit
import ActivityKit

@main struct CuikeWidgetBundle: WidgetBundle {
    var body: some Widget { LastRecipeWidget(); BrewLiveActivity() }
}

struct RecipeEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedRecipeSnapshot?
}

struct RecipeProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecipeEntry {
        RecipeEntry(date: Date(), snapshot: SharedRecipeSnapshot(version: 1,
            recipeID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            beanName: "柑橘晨光", dose: 15, water: 240, temperature: 92, updatedAt: Date()))
    }
    func getSnapshot(in context: Context, completion: @escaping (RecipeEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : RecipeEntry(date: Date(), snapshot: SharedStorage.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecipeEntry>) -> Void) {
        completion(Timeline(entries: [RecipeEntry(date: Date(), snapshot: SharedStorage.read())], policy: .never))
    }
}

struct LastRecipeWidget: Widget {
    let kind = "LastRecipeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecipeProvider()) { entry in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("萃刻").font(.caption.bold())
                    Spacer()
                    Image(systemName: "cup.and.saucer.fill").foregroundStyle(Color("AccentColor"))
                }
                Spacer(minLength: 0)
                if let snapshot = entry.snapshot {
                    Text(snapshot.beanName).font(.headline)
                    Text("\(snapshot.dose)g · \(snapshot.water)g 水 · \(snapshot.temperature)℃").font(.caption).foregroundStyle(.secondary)
                    Label("打开配方", systemImage: "arrow.up.right").font(.caption.bold()).foregroundStyle(Color("AccentColor"))
                } else {
                    Text("从一杯好咖啡开始").font(.headline)
                    Text("打开萃刻，保存一份配方").font(.caption).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(Color("Ink"))
            .containerBackground(Color("Paper"), for: .widget)
            .widgetURL(entry.snapshot?.url ?? URL(string: "cuike://last-recipe")!)
        }
        .configurationDisplayName("再冲一杯").description("打开最近使用的配方，由你确认后开始冲煮。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BrewLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrewActivityAttributes.self) { context in
            HStack(spacing: 18) {
                Image(systemName: "cup.and.saucer.fill").font(.title).foregroundStyle(Color("AccentColor"))
                VStack(alignment: .leading, spacing: 6) {
                    Text("萃刻 · \(context.attributes.beanName)").font(.headline)
                    Text(context.isStale || context.state.finished ? "预设时间已到 · 回到萃刻记录" : "目标 \(context.attributes.water)g · 慢慢冲，好好喝")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                countdown(context).font(.title2.monospacedDigit()).frame(maxWidth: 85)
            }
            .padding(20).activityBackgroundTint(Color("Paper"))
            .activitySystemActionForegroundColor(Color("Ink"))
            .widgetURL(URL(string: "cuike://brew/\(context.attributes.sessionID.uuidString)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange).padding(.leading, 8) }
                DynamicIslandExpandedRegion(.trailing) { countdown(context).font(.title2.monospacedDigit()).padding(.trailing, 8) }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.beanName)
                        Spacer()
                        Text(context.isStale ? "回到萃刻记录" : "目标 \(context.attributes.water)g").foregroundStyle(.secondary)
                    }.font(.subheadline).padding(8)
                }
            } compactLeading: {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context).monospacedDigit().frame(width: 50)
            } minimal: {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "cuike://brew/\(context.attributes.sessionID.uuidString)"))
        }
    }
    @ViewBuilder private func countdown(_ context: ActivityViewContext<BrewActivityAttributes>) -> some View {
        if context.state.finished || context.isStale { Text("完成") }
        else { Text(timerInterval: context.attributes.startDate...max(context.attributes.startDate, context.state.endDate), countsDown: true) }
    }
}
