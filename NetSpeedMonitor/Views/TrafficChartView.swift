import Charts
import Foundation
import SwiftUI

struct TrafficChartView: View {
    let samples: [NetworkSample]
    let range: HistoryRange
    let isPaused: Bool
    var compact = false

    var body: some View {
        let now = Date()
        let yAxis = TrafficAxisScale(samples: samples)
        let downloadColor: Color = isPaused ? .yellow : .blue
        let uploadColor: Color = isPaused ? .yellow.opacity(0.72) : .mint

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
                            colors: [downloadColor.opacity(0.28), downloadColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("Download", sample.downloadBytesPerSecond)
                    )
                    .foregroundStyle(downloadColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("Upload", sample.uploadBytesPerSecond)
                    )
                    .foregroundStyle(uploadColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: now.addingTimeInterval(-range.duration)...now)
                .chartYScale(domain: 0...yAxis.ceiling)
                .chartXAxis(compact ? .hidden : .automatic)
                .chartYAxis {
                    AxisMarks(position: .leading, values: yAxis.tickValues) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bytes = value.as(Double.self) {
                                Text(yAxis.label(for: bytes))
                            }
                        }
                    }
                }
                .accessibilityLabel("Network traffic chart")
                .animation(.easeInOut(duration: 0.2), value: isPaused)
            }
        }
    }
}

private struct TrafficAxisScale {
    let ceiling: Double
    let unitScale: Double
    let unit: String

    init(samples: [NetworkSample]) {
        let maximum = samples.reduce(0) { currentMaximum, sample in
            max(
                currentMaximum,
                max(sample.uploadBytesPerSecond, sample.downloadBytesPerSecond)
            )
        }

        let units: [(scale: Double, name: String)] = [
            (1, "B"),
            (1_024, "KB"),
            (1_048_576, "MB"),
            (1_073_741_824, "GB"),
            (1_099_511_627_776, "TB")
        ]
        let selectedUnit = units.last(where: { maximum >= $0.scale }) ?? units[0]
        unitScale = selectedUnit.scale
        unit = selectedUnit.name

        let scaledMaximum = max(maximum / unitScale, 1)
        let magnitude = pow(10, floor(log10(scaledMaximum)))
        let normalizedMaximum = scaledMaximum / magnitude
        let roundedMaximum: Double
        switch normalizedMaximum {
        case ...1: roundedMaximum = 1
        case ...2: roundedMaximum = 2
        case ...5: roundedMaximum = 5
        default: roundedMaximum = 10
        }
        ceiling = roundedMaximum * magnitude * unitScale
    }

    var tickValues: [Double] {
        (0...4).map { ceiling * Double($0) / 4 }
    }

    func label(for bytes: Double) -> String {
        let value = bytes / unitScale
        let formattedValue = value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formattedValue) \(unit)/s"
    }
}
