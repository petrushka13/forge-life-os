import DeviceActivity
import ExtensionKit
import SwiftUI

@main struct ForgeReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene { UsageScene { UsageView(minutes:$0) } }
}
nonisolated struct UsageScene: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("FORGE Total Usage")
    let content: (Double) -> UsageView
    func makeConfiguration(representing data:DeviceActivityResults<DeviceActivityData>) async -> Double {
        var seconds=0.0
        for await item in data { for await segment in item.activitySegments { seconds += segment.totalActivityDuration } }
        return seconds/60
    }
}
struct UsageView: View {
    let minutes:Double
    var body:some View { VStack { Text("Today's Screen Time").font(.headline); Text("\(Int(max(0,minutes))) minutes").font(.title); Text("Private Apple report. Not exported to FORGE scoring or AI.").font(.caption) } }
}
