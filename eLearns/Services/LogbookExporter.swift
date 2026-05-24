import UIKit
import UniformTypeIdentifiers

enum LogbookExporter {

    // MARK: - PDF

    static func exportPDF(entries: [LogEntry], profile: UserProfile) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext

            var y: CGFloat = 40

            // Title
            y = drawText("eLearns Logbook", at: CGPoint(x: 40, y: y),
                         font: .systemFont(ofSize: 24, weight: .bold), color: .black, maxWidth: 515)
            y += 6
            y = drawText("Driver: \(profile.name.isEmpty ? "—" : profile.name)  |  Licence: \(profile.licenceType.displayName)",
                         at: CGPoint(x: 40, y: y),
                         font: .systemFont(ofSize: 12), color: .darkGray, maxWidth: 515)
            y += 4

            let dayH = appState_totalMinutes(entries: entries, night: false)
            let nightH = appState_totalMinutes(entries: entries, night: true)
            y = drawText("Total day: \(dayH / 60)h \(dayH % 60)m  |  Total night: \(nightH / 60)h \(nightH % 60)m",
                         at: CGPoint(x: 40, y: y),
                         font: .systemFont(ofSize: 12), color: .darkGray, maxWidth: 515)
            y += 16

            // Header row
            let cols: [(String, CGFloat)] = [
                ("Date", 80), ("Duration", 70), ("Distance", 70),
                ("Type", 50), ("Supervisor", 120), ("Notes", 125)
            ]
            cgCtx.setFillColor(UIColor(red: 0.95, green: 0.80, blue: 0.26, alpha: 1).cgColor)
            cgCtx.fill(CGRect(x: 40, y: y, width: 515, height: 20))

            var x: CGFloat = 40
            for (title, width) in cols {
                drawText(title, at: CGPoint(x: x + 4, y: y + 3),
                         font: .systemFont(ofSize: 10, weight: .semibold), color: .black, maxWidth: width - 8)
                x += width
            }
            y += 20

            // Rows
            for (i, entry) in entries.enumerated() {
                if y > 800 {
                    ctx.beginPage()
                    y = 40
                }

                let bg: UIColor = i % 2 == 0 ? .white : UIColor(white: 0.96, alpha: 1)
                cgCtx.setFillColor(bg.cgColor)
                cgCtx.fill(CGRect(x: 40, y: y, width: 515, height: 18))

                let rowData: [(String, CGFloat)] = [
                    (entry.date.formatted(date: .abbreviated, time: .omitted), 80),
                    ("\(entry.durationMinutes) min", 70),
                    (String(format: "%.1f km", entry.distanceKm), 70),
                    (entry.isNight ? "Night" : "Day", 50),
                    (entry.supervisorName, 120),
                    (entry.notes, 125)
                ]
                x = 40
                for (value, width) in rowData {
                    drawText(value, at: CGPoint(x: x + 4, y: y + 4),
                             font: .systemFont(ofSize: 9), color: .black, maxWidth: width - 8)
                    x += width
                }
                y += 18
            }
        }

        return writeTemp(data: data, filename: "eLearns_Logbook.pdf")
    }

    // MARK: - CSV (opens in Excel / Numbers)

    static func exportCSV(entries: [LogEntry], profile: UserProfile) -> URL? {
        var lines: [String] = []

        // Header info
        lines.append("eLearns Logbook")
        lines.append("Driver,\(profile.name)")
        lines.append("Licence,\(profile.licenceType.displayName)")
        lines.append("")

        // Column headers
        lines.append("Date,Duration (min),Distance (km),Type,Supervisor,Notes")

        // Data rows
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        for entry in entries {
            let fields: [String] = [
                df.string(from: entry.date),
                "\(entry.durationMinutes)",
                String(format: "%.1f", entry.distanceKm),
                entry.isNight ? "Night" : "Day",
                csvEscape(entry.supervisorName),
                csvEscape(entry.notes)
            ]
            lines.append(fields.joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else { return nil }
        return writeTemp(data: data, filename: "eLearns_Logbook.csv")
    }

    // MARK: - Helpers

    @discardableResult
    private static func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor,
        maxWidth: CGFloat
    ) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = NSAttributedString(string: text, attributes: attrs)
        let bounds = str.boundingRect(
            with: CGSize(width: maxWidth, height: 400),
            options: .usesLineFragmentOrigin,
            context: nil
        )
        str.draw(in: CGRect(origin: point, size: bounds.size))
        return point.y + bounds.height
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func writeTemp(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    private static func appState_totalMinutes(entries: [LogEntry], night: Bool) -> Int {
        entries.filter { $0.isNight == night }.reduce(0) { $0 + $1.durationMinutes }
    }
}