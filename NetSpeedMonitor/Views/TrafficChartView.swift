import Charts
import SwiftUI

struct TrafficChartView: View {
    let samples: [NetworkSample]
    var compact = false

    var body: some View {
        Group {
            if samples.isEmpty {
                ContentUnavailableView(
                    "Gathering traffic",
                    systemImage: "waveform.path.ecg",
                    description: Text("The chart will appear after the next network sample.")
                )
            } else {
                Chart(samples) { sample in
                    AreaMark(
                        x: .value("Time", sample.date),
                        y: .value("Download", sample.downloadBytesPerSecond)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue.opacity(0.28), .blue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("Download", sample.downloadBytesPerSecond)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("Upload", sample.uploadBytesPerSecond)
                    )
                    .foregroundStyle(.mint)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(compact ? .hidden : .automatic)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bytes = value.as(Double.self) {
                                Text(NetworkValueFormatter.rate(bytes))
                            }
                        }
                    }
                }
                .accessibilityLabel("Network traffic chart")
            }
        }
    }
}
