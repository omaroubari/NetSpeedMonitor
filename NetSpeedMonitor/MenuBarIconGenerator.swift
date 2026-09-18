import AppKit

final class MenuBarIconGenerator {
    private static let rowHeight: CGFloat = 11
    private static let imageHeight = rowHeight * 2
    private static let segmentCount = 6
    private static let segmentWidth: CGFloat = 2
    private static let segmentSpacing: CGFloat = 1
    private static let meterHeight: CGFloat = 9
    private static let textSpacing: CGFloat = 4
    private static let numberColumnWidth: CGFloat = 25 // Width of "1000" at 9pt.
    private static let unitColumnWidth: CGFloat = 25
    private static let meterWidth = CGFloat(segmentCount) * segmentWidth
        + CGFloat(segmentCount - 1) * segmentSpacing
    private static let textOriginX = meterWidth + textSpacing
    private static let imageWidth = textOriginX + numberColumnWidth + unitColumnWidth

    static func generateIcon(
        speeds: NetworkSpeeds,
        uploadActivity: Double,
        downloadActivity: Double
    ) -> NSImage {
        let imageSize = NSSize(width: imageWidth, height: imageHeight)

        let image = NSImage(size: imageSize, flipped: false) { _ in
            drawRow(speed: speeds.upload, activity: uploadActivity, y: rowHeight)
            drawRow(speed: speeds.download, activity: downloadActivity, y: 0)
            return true
        }

        image.isTemplate = true
        return image
    }

    private static func drawRow(
        speed: NetworkSpeed,
        activity: Double,
        y: CGFloat
    ) {
        drawActivityMeter(level: activity, y: y)

        makeNumberText(for: speed).draw(
            in: NSRect(x: textOriginX, y: y, width: numberColumnWidth, height: rowHeight)
        )
        makeUnitText(for: speed).draw(
            in: NSRect(
                x: textOriginX + numberColumnWidth,
                y: y,
                width: unitColumnWidth,
                height: rowHeight
            )
        )
    }

    private static func makeNumberText(for speed: NetworkSpeed) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: speed.displayValue, attributes: numberAttributes)
    }

    private static func makeUnitText(for speed: NetworkSpeed) -> NSAttributedString {
        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.68)
        ]

        return NSAttributedString(
            string: " \(speed.unit)/s",
            attributes: unitAttributes
        )
    }

    private static func drawActivityMeter(level: Double, y: CGFloat) {
        let activeSegmentCount = Int(ceil(
            min(max(level, 0), 1) * Double(segmentCount)
        ))
        let meterY = y + (rowHeight - meterHeight) / 2

        for index in 0..<segmentCount {
            let x = CGFloat(index) * (segmentWidth + segmentSpacing)
            let trackRect = NSRect(
                x: x,
                y: meterY,
                width: segmentWidth,
                height: meterHeight
            )

            NSColor.labelColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: trackRect, xRadius: 0.6, yRadius: 0.6).fill()

            guard index < activeSegmentCount else { continue }
            NSColor.labelColor.setFill()
            NSBezierPath(roundedRect: trackRect, xRadius: 0.6, yRadius: 0.6).fill()
        }
    }
}
