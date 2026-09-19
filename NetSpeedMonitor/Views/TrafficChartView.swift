import Charts
import Foundation
import SwiftUI

struct TrafficChartView: View {
    let samples: [NetworkSample]
    let range: HistoryRange
    let isPaused: Bool
    var compact = false
    var showsDetails = false
    @State private var selectedDate: Date?
    @State private var hoverLocation: CGPoint?
    private let tooltipSize = CGSize(width: 240, height: 110)

    private var interpolatedSample: NetworkSample? {
        guard let selectedDate, !samples.isEmpty else { return nil }

        var lowerBound = 0
        var upperBound = samples.count
        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if samples[midpoint].date < selectedDate {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        guard lowerBound > 0 else {
            return sample(at: selectedDate, ratesFrom: samples[0], metadataFrom: samples[0])
        }
        guard lowerBound < samples.count else {
            let lastSample = samples[samples.count - 1]
            return sample(at: selectedDate, ratesFrom: lastSample, metadataFrom: lastSample)
        }

        let earlier = samples[lowerBound - 1]
        let later = samples[lowerBound]
        let duration = later.date.timeIntervalSince(earlier.date)
        let progress = duration > 0
            ? min(max(selectedDate.timeIntervalSince(earlier.date) / duration, 0), 1)
            : 0
        let metadataSample = progress <= 0.5 ? earlier : later
        let rates = NetworkSample(
            date: selectedDate,
            uploadBytesPerSecond: earlier.uploadBytesPerSecond
                + (later.uploadBytesPerSecond - earlier.uploadBytesPerSecond) * progress,
            downloadBytesPerSecond: earlier.downloadBytesPerSecond
                + (later.downloadBytesPerSecond - earlier.downloadBytesPerSecond) * progress
        )
        return sample(at: selectedDate, ratesFrom: rates, metadataFrom: metadataSample)
    }

    var body: some View {
        let now = Date()
        let yAxis = TrafficAxisScale(samples: samples)
        let downloadColor: Color = isPaused ? .yellow : .blue
        let uploadColor: Color = isPaused ? .yellow.opacity(0.72) : .mint
        let hoveredSample = interpolatedSample

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
                    .interpolationMethod(showsDetails ? .linear : .catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("Download", sample.downloadBytesPerSecond)
                    )
                    .foregroundStyle(downloadColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(showsDetails ? .linear : .catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value("Upload", sample.uploadBytesPerSecond)
                    )
                    .foregroundStyle(uploadColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(showsDetails ? .linear : .catmullRom)

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
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if showsDetails, let plotFrame = proxy.plotFrame {
                            let frame = geometry[plotFrame]
                            ZStack(alignment: .topLeading) {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case let .active(location):
                                            guard frame.contains(location) else {
                                                selectedDate = nil
                                                hoverLocation = nil
                                                return
                                            }
                                            selectedDate = proxy.value(
                                                atX: location.x - frame.minX,
                                                as: Date.self
                                            )
                                            hoverLocation = location
                                        case .ended:
                                            selectedDate = nil
                                            hoverLocation = nil
                                        }
                                    }

                                if let hoverLocation {
                                    Path { path in
                                        let x = hoverLocation.x
                                        path.move(to: CGPoint(x: x, y: frame.minY))
                                        path.addLine(to: CGPoint(x: x, y: frame.maxY))
                                    }
                                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .allowsHitTesting(false)
                                }

                                if let hoveredSample, let hoverLocation {
                                    if let downloadY = proxy.position(
                                        forY: hoveredSample.downloadBytesPerSecond
                                    ) {
                                        Circle()
                                            .fill(downloadColor)
                                            .stroke(.background, lineWidth: 2)
                                            .frame(width: 8, height: 8)
                                            .position(
                                                x: hoverLocation.x,
                                                y: frame.minY + downloadY
                                            )
                                            .allowsHitTesting(false)
                                    }

                                    if let uploadY = proxy.position(
                                        forY: hoveredSample.uploadBytesPerSecond
                                    ) {
                                        Circle()
                                            .fill(uploadColor)
                                            .stroke(.background, lineWidth: 2)
                                            .frame(width: 8, height: 8)
                                            .position(
                                                x: hoverLocation.x,
                                                y: frame.minY + uploadY
                                            )
                                            .allowsHitTesting(false)
                                    }

                                    TrafficSampleDetails(sample: hoveredSample, range: range)
                                        .frame(width: tooltipSize.width, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .position(tooltipPosition(
                                            cursor: hoverLocation,
                                            tooltipSize: tooltipSize,
                                            plotFrame: frame
                                        ))
                                        .animation(
                                            .interactiveSpring(response: 0.1, dampingFraction: 0.95),
                                            value: hoverLocation
                                        )
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sample(
        at date: Date,
        ratesFrom rates: NetworkSample,
        metadataFrom metadata: NetworkSample
    ) -> NetworkSample {
        NetworkSample(
            date: date,
            uploadBytesPerSecond: rates.uploadBytesPerSecond,
            downloadBytesPerSecond: rates.downloadBytesPerSecond,
            interval: metadata.interval,
            uploadedBytes: metadata.uploadedBytes,
            downloadedBytes: metadata.downloadedBytes,
            peakUploadBytesPerSecond: metadata.peakUploadBytesPerSecond,
            peakDownloadBytesPerSecond: metadata.peakDownloadBytesPerSecond,
            sampleCount: metadata.sampleCount
        )
    }

    private func tooltipPosition(
        cursor: CGPoint,
        tooltipSize: CGSize,
        plotFrame: CGRect
    ) -> CGPoint {
        let edgePadding: CGFloat = 12
        let cursorGap: CGFloat = 14
        let halfWidth = tooltipSize.width / 2
        let halfHeight = tooltipSize.height / 2

        let minimumX = plotFrame.minX + edgePadding + halfWidth
        let maximumX = plotFrame.maxX - edgePadding - halfWidth
        let minimumY = plotFrame.minY + edgePadding + halfHeight
        let maximumY = plotFrame.maxY - edgePadding - halfHeight

        var x = cursor.x + cursorGap + halfWidth
        x = minimumX <= maximumX
            ? min(max(x, minimumX), maximumX)
            : plotFrame.midX

        var y = cursor.y - cursorGap - halfHeight
        y = minimumY <= maximumY
            ? min(max(y, minimumY), maximumY)
            : plotFrame.midY

        return CGPoint(x: x, y: y)
    }
}

private struct TrafficSampleDetails: View {
    let sample: NetworkSample
    let range: HistoryRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sample.date, format: dateFormat)
                .font(.caption.bold())
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow {
                    Text("Average")
                    Text("↓ \(NetworkValueFormatter.rate(sample.downloadBytesPerSecond))")
                    Text("↑ \(NetworkValueFormatter.rate(sample.uploadBytesPerSecond))")
                }
                GridRow {
                    Text("Transferred")
                    Text("↓ \(NetworkValueFormatter.bytes(Double(sample.downloadedBytes)))")
                    Text("↑ \(NetworkValueFormatter.bytes(Double(sample.uploadedBytes)))")
                }
                GridRow {
                    Text("Peak")
                    Text("↓ \(NetworkValueFormatter.rate(sample.peakDownloadBytesPerSecond))")
                    Text("↑ \(NetworkValueFormatter.rate(sample.peakUploadBytesPerSecond))")
                }
                GridRow {
                    Text("Samples")
                    Text("\(sample.sampleCount)")
                    Text(durationText)
                }
            }
            .font(.caption2)
            .monospacedDigit()
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var dateFormat: Date.FormatStyle {
        if range == .sevenDays {
            return .dateTime.weekday(.abbreviated).hour().minute()
        }
        return .dateTime.hour().minute().second()
    }

    private var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = sample.interval >= 60 * 60 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: sample.interval) ?? ""
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
