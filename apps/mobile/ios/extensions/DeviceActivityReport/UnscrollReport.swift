import DeviceActivity
import SwiftUI

/// Apple renders usage inside this extension so the numbers never reach the
/// main app. The main app embeds it with a `DeviceActivityReport` view.
@main
struct UnscrollReport: DeviceActivityReportExtension {
  var body: some DeviceActivityReportScene {
    TotalActivityReport { total in
      VStack(alignment: .leading, spacing: 4) {
        Text("Screen time").font(.subheadline).foregroundColor(.secondary)
        Text(total).font(.largeTitle.weight(.semibold))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
  }
}

extension DeviceActivityReport.Context {
  static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport<Content: View>: DeviceActivityReportScene {
  let context: DeviceActivityReport.Context = .totalActivity
  let content: (String) -> Content

  func makeConfiguration(
    representing data: DeviceActivityResults<DeviceActivityData>
  ) async -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated
    formatter.zeroFormattingBehavior = .dropAll
    let total = await data.flatMap { $0.activitySegments }.reduce(0) {
      $0 + $1.totalActivityDuration
    }
    return formatter.string(from: total) ?? "0m"
  }
}
