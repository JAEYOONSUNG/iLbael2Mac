import Foundation

enum ProductFamily: String, Codable, CaseIterable, Identifiable {
    case a4Label
    case a3Label
    case zLabel
    case rollLabel
    case a4Tag
    case zTag
    case rollTag

    var id: String { rawValue }

    var label: String {
        switch self {
        case .a4Label:
            return "A4 Label"
        case .a3Label:
            return "A3 Label"
        case .zLabel:
            return "Jet Label"
        case .rollLabel:
            return "Roll Label"
        case .a4Tag:
            return "A4 Tag"
        case .zTag:
            return "Jet Tag"
        case .rollTag:
            return "Roll Tag"
        }
    }
}

struct OfficialFormatDefinition: Codable, Identifiable, Hashable {
    var code: String
    var name: String
    var family: ProductFamily
    var familyLabel: String
    var sourceURL: String
    var detailURL: String
    var pdfTemplateURL: String?
    var pageWidthMM: Double
    var pageHeightMM: Double
    var columns: Int
    var rows: Int
    var labelWidthMM: Double
    var labelHeightMM: Double
    var horizontalGapMM: Double
    var verticalGapMM: Double
    var marginLeftMM: Double
    var marginTopMM: Double
    var marginRightMM: Double
    var marginBottomMM: Double
    var labelsPerPage: Int
    var cornerRadiusMM: Double
    var shape: LabelShape
    var officialType: String
    var continuous: Bool

    var id: String { code }

    var sizeSummary: String {
        if continuous {
            return "\(formatMillimeters(labelWidthMM)) x \(formatMillimeters(labelHeightMM)) mm"
        }
        return "\(columns)x\(rows) · \(formatMillimeters(labelWidthMM)) x \(formatMillimeters(labelHeightMM)) mm"
    }

    var detailSummary: String {
        if continuous {
            return "\(family.label) · \(officialType)"
        }
        return "\(family.label) · \(labelsPerPage) up"
    }

    var sheetTemplate: SheetTemplate {
        SheetTemplate(
            id: code,
            name: name,
            pageWidthMM: pageWidthMM,
            pageHeightMM: pageHeightMM,
            columns: max(columns, 1),
            rows: max(rows, 1),
            labelWidthMM: labelWidthMM,
            labelHeightMM: labelHeightMM,
            horizontalGapMM: horizontalGapMM,
            verticalGapMM: verticalGapMM,
            marginLeftMM: marginLeftMM,
            marginTopMM: marginTopMM,
            shape: shape,
            cornerRadiusMM: cornerRadiusMM
        )
    }

    private func formatMillimeters(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == floor(rounded) {
            return String(Int(rounded))
        }
        return String(format: "%.2f", rounded)
    }
}

struct OfficialFormatPayload: Codable {
    var generatedAt: String
    var source: String
    var count: Int
    var formats: [OfficialFormatDefinition]
}

enum OfficialFormatCatalog {
    static func load() -> [OfficialFormatDefinition] {
        for url in candidateURLs() {
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            if let data = try? Data(contentsOf: url),
               let payload = try? JSONDecoder().decode(OfficialFormatPayload.self, from: data) {
                return payload.formats
                    .map(normalize)
                    .sorted { lhs, rhs in
                    if lhs.family == rhs.family {
                        return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
                    }
                    return lhs.family.label < rhs.family.label
                }
            }
        }

        return fallback
    }

    static func normalize(_ format: OfficialFormatDefinition) -> OfficialFormatDefinition {
        guard format.code == "680" else { return format }
        var updated = format
        updated.marginLeftMM = 8.0
        updated.marginRightMM = 8.0
        updated.marginTopMM = 9.5
        updated.marginBottomMM = 9.5
        updated.horizontalGapMM = 2.0
        updated.verticalGapMM = 2.0
        updated.labelWidthMM = 12.0
        updated.labelHeightMM = 12.0
        updated.cornerRadiusMM = 6.0
        updated.shape = .circle
        return updated
    }

    private static func candidateURLs() -> [URL] {
        let fileManager = FileManager.default
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let bundleResources = Bundle.main.resourceURL

        return [
            bundleResources?.appendingPathComponent("official_formats.json"),
            currentDirectory.appendingPathComponent("Resources/official_formats.json"),
            executableDirectory.appendingPathComponent("official_formats.json"),
            executableDirectory.appendingPathComponent("../Resources/official_formats.json").standardizedFileURL,
            executableDirectory.appendingPathComponent("../../Resources/official_formats.json").standardizedFileURL
        ].compactMap { $0 }
    }

    static let fallback: [OfficialFormatDefinition] = [
        OfficialFormatDefinition(
            code: "680",
            name: "680 · A4 Label",
            family: .a4Label,
            familyLabel: "A4 Label",
            sourceURL: "https://www.label.kr/Goods/A4Label/ByCuts",
            detailURL: "https://www.label.kr/Goods/Detail/680",
            pdfTemplateURL: "https://images.label.kr/pds/template/680_line.pdf",
            pageWidthMM: 210,
            pageHeightMM: 297,
            columns: 14,
            rows: 20,
            labelWidthMM: 12,
            labelHeightMM: 12,
            horizontalGapMM: 2,
            verticalGapMM: 2,
            marginLeftMM: 8,
            marginTopMM: 9.5,
            marginRightMM: 8,
            marginBottomMM: 9.5,
            labelsPerPage: 280,
            cornerRadiusMM: 6,
            shape: .circle,
            officialType: "circle",
            continuous: false
        ),
        OfficialFormatDefinition(
            code: "954",
            name: "954 · A4 Label",
            family: .a4Label,
            familyLabel: "A4 Label",
            sourceURL: "https://www.label.kr/Goods/A4Label/ByCuts",
            detailURL: "https://www.label.kr/Goods/Detail/954",
            pdfTemplateURL: "https://images.label.kr/pds/template/954_line.pdf",
            pageWidthMM: 210,
            pageHeightMM: 297,
            columns: 6,
            rows: 9,
            labelWidthMM: 30,
            labelHeightMM: 30,
            horizontalGapMM: 3,
            verticalGapMM: 2,
            marginLeftMM: 7.5,
            marginTopMM: 5.5,
            marginRightMM: 7.5,
            marginBottomMM: 5.5,
            labelsPerPage: 54,
            cornerRadiusMM: 0,
            shape: .rectangle,
            officialType: "rectangle-sc",
            continuous: false
        ),
        OfficialFormatDefinition(
            code: "611",
            name: "611 · A4 Label",
            family: .a4Label,
            familyLabel: "A4 Label",
            sourceURL: "https://www.label.kr/Goods/A4Label/ByCuts",
            detailURL: "https://www.label.kr/Goods/Detail/611",
            pdfTemplateURL: "https://images.label.kr/pds/template/611_line.pdf",
            pageWidthMM: 210,
            pageHeightMM: 297,
            columns: 1,
            rows: 1,
            labelWidthMM: 210,
            labelHeightMM: 297,
            horizontalGapMM: 0,
            verticalGapMM: 0,
            marginLeftMM: 0,
            marginTopMM: 0,
            marginRightMM: 0,
            marginBottomMM: 0,
            labelsPerPage: 1,
            cornerRadiusMM: 0,
            shape: .rectangle,
            officialType: "rectangle-sc",
            continuous: false
        ),
        OfficialFormatDefinition(
            code: "ZL030020",
            name: "ZL030020 · Jet Label",
            family: .zLabel,
            familyLabel: "Jet Label",
            sourceURL: "https://www.label.kr/Goods/ZLabel/ByPrinter/Direct-Thermal",
            detailURL: "https://www.label.kr/Goods/Detail/ZL030020",
            pdfTemplateURL: nil,
            pageWidthMM: 30,
            pageHeightMM: 20.283,
            columns: 1,
            rows: 1,
            labelWidthMM: 30,
            labelHeightMM: 20.283,
            horizontalGapMM: 0,
            verticalGapMM: 0,
            marginLeftMM: 0,
            marginTopMM: 0,
            marginRightMM: 0,
            marginBottomMM: 0,
            labelsPerPage: 1,
            cornerRadiusMM: 2,
            shape: .roundedRectangle,
            officialType: "rectangle-rc",
            continuous: true
        )
    ]
}
