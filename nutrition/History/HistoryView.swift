import SwiftUI
import Charts


// History sub-app: trend charts (Swift Charts, iOS 16+), numeric
// trend deltas, and a scrollable list of every logged day. Tap a
// day to drill into its full snapshot (DayLogDetail).
struct HistoryView: View {

    @EnvironmentObject var dayLogMgr: DayLogMgr
    @EnvironmentObject var profileMgr: ProfileMgr

    // Only the active profile's days — charts, trends, and the
    // list all derive from this filtered set.
    private var sortedLogs: [DayLog] {
        dayLogMgr.logs
          .filter { $0.profileId == profileMgr.activeProfileId }
          .sorted { $0.date > $1.date }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    var body: some View {
        Group {
            if sortedLogs.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        TrendCharts(logs: sortedLogs)
                    } header: {
                        Text("Charts")
                    }

                    Section {
                        TrendSummary(logs: sortedLogs)
                    } header: {
                        Text("Trends")
                    }

                    Section {
                        ForEach(sortedLogs) { log in
                            NavigationLink(destination: DayLogDetail(log: log)) {
                                DayLogRow(log: log, dateLabel: dateLabel(log.date))
                            }
                        }
                    } header: {
                        Text("Logged Days (\(sortedLogs.count))")
                    } footer: {
                        Text("Tap a day for its full snapshot — every entry, all vitamins & minerals, and body params.")
                          .font(.caption2)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                    }
                }
                  .listStyle(InsetGroupedListStyle())
            }
        }
          .navigationTitle("History")
          .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
              .font(.system(size: 44))
              .foregroundColor(Color.theme.blackWhiteSecondary)
            Text("No history yet")
              .font(.headline)
              .foregroundColor(Color.theme.blackWhite)
            Text("Open the meal summary and tap \"Log Today\" to capture a daily snapshot. Logged days appear here.")
              .font(.callout)
              .multilineTextAlignment(.center)
              .foregroundColor(Color.theme.blackWhiteSecondary)
              .padding(.horizontal, 32)
        }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// A single day's at-a-glance row: date, calories, cost, weight.
struct DayLogRow: View {
    let log: DayLog
    let dateLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLabel)
              .font(.callout)
              .foregroundColor(Color.theme.blackWhite)
            HStack(spacing: 14) {
                metric("\(log.totals.calories.formattedString(0)) cal")
                metric("$\(log.totals.cost.formattedString(2))")
                if let w = log.body.weightLbs {
                    metric("\(w.formattedString(1)) lbs")
                }
            }
        }
          .padding(.vertical, 2)
    }

    private func metric(_ s: String) -> some View {
        Text(s)
          .font(.caption)
          .foregroundColor(Color.theme.blueYellow)
    }
}


// Numeric trend block (oldest → newest deltas). Replaces charts on
// the iOS 15 target; gives weight / calories / cost / protein
// movement at a glance.
struct TrendSummary: View {
    let logs: [DayLog]   // newest first

    private var oldest: DayLog? { logs.last }
    private var newest: DayLog? { logs.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if logs.count < 2 {
                Text("Log a second day to see trends.")
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            } else if let o = oldest, let n = newest {
                trendRow("Weight",
                         from: o.body.weightLbs,
                         to: n.body.weightLbs,
                         unit: "lbs", precision: 1)
                trendRow("Calories",
                         from: o.totals.calories,
                         to: n.totals.calories,
                         unit: "cal", precision: 0)
                trendRow("Cost",
                         from: o.totals.cost,
                         to: n.totals.cost,
                         unit: "$", precision: 2, dollarPrefix: true)
                trendRow("Protein",
                         from: o.totals.protein,
                         to: n.totals.protein,
                         unit: "g", precision: 0)
                trendRow("Net Carbs",
                         from: o.totals.netCarbs,
                         to: n.totals.netCarbs,
                         unit: "g", precision: 0)
            }
        }
          .padding(.vertical, 4)
    }

    @ViewBuilder
    private func trendRow(_ name: String,
                          from: Double?,
                          to: Double?,
                          unit: String,
                          precision: Int,
                          dollarPrefix: Bool = false) -> some View {
        if let a = from, let b = to {
            let delta = b - a
            let arrow = delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus")
            HStack {
                Text(name)
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhite)
                Spacer()
                Text(format(b, precision, dollarPrefix, unit))
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhite)
                HStack(spacing: 2) {
                    Image(systemName: arrow)
                      .font(.caption2)
                    Text(format(abs(delta), precision, dollarPrefix, unit))
                      .font(.caption2)
                }
                  .foregroundColor(Color.theme.blueYellow)
                  .frame(width: 86, alignment: .trailing)
            }
        }
    }

    private func format(_ v: Double, _ p: Int, _ dollar: Bool, _ unit: String) -> String {
        if dollar { return "$" + v.formattedString(p) }
        return v.formattedString(p) + " " + unit
    }
}


// Swift Charts trends over the logged days (chronological,
// oldest → newest). Requires iOS 16+ (project now targets 16.0).
struct TrendCharts: View {
    let logs: [DayLog]            // any order

    private var chrono: [DayLog] { logs.sorted { $0.date < $1.date } }

    var body: some View {
        if chrono.count < 2 {
            Text("Log at least two days to see charts.")
              .font(.caption)
              .foregroundColor(Color.theme.blackWhiteSecondary)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                weightChart
                caloriesChart
                costChart
                macrosChart
            }
              .padding(.vertical, 4)
        }
    }

    private func title(_ s: String) -> some View {
        Text(s)
          .font(.caption)
          .foregroundColor(Color.theme.blackWhiteSecondary)
    }

    private var weightChart: some View {
        let pts = chrono.filter { $0.body.weightLbs != nil }
        return VStack(alignment: .leading, spacing: 4) {
            title("Weight (lbs)")
            if pts.count < 2 {
                Text("Need ≥2 days with a weight.")
                  .font(.caption2)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            } else {
                Chart(pts) { d in
                    LineMark(x: .value("Day", d.date),
                             y: .value("lbs", d.body.weightLbs ?? 0))
                    PointMark(x: .value("Day", d.date),
                              y: .value("lbs", d.body.weightLbs ?? 0))
                }
                  .frame(height: 140)
            }
        }
    }

    private var caloriesChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            title("Calories")
            Chart(chrono) { d in
                LineMark(x: .value("Day", d.date),
                         y: .value("cal", d.totals.calories))
                PointMark(x: .value("Day", d.date),
                          y: .value("cal", d.totals.calories))
            }
              .frame(height: 140)
        }
    }

    private var costChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            title("Cost ($)")
            Chart(chrono) { d in
                LineMark(x: .value("Day", d.date),
                         y: .value("$", d.totals.cost))
                PointMark(x: .value("Day", d.date),
                          y: .value("$", d.totals.cost))
            }
              .frame(height: 140)
        }
    }

    private var macrosChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            title("Macros (g)")
            Chart(chrono) { d in
                LineMark(x: .value("Day", d.date),
                         y: .value("g", d.totals.protein),
                         series: .value("Macro", "Protein"))
                  .foregroundStyle(by: .value("Macro", "Protein"))
                LineMark(x: .value("Day", d.date),
                         y: .value("g", d.totals.netCarbs),
                         series: .value("Macro", "Net Carbs"))
                  .foregroundStyle(by: .value("Macro", "Net Carbs"))
                LineMark(x: .value("Day", d.date),
                         y: .value("g", d.totals.fat),
                         series: .value("Macro", "Fat"))
                  .foregroundStyle(by: .value("Macro", "Fat"))
                LineMark(x: .value("Day", d.date),
                         y: .value("g", d.totals.fiber),
                         series: .value("Macro", "Fiber"))
                  .foregroundStyle(by: .value("Macro", "Fiber"))
            }
              .frame(height: 160)
        }
    }
}
