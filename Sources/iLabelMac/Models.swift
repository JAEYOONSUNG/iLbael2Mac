import SwiftUI
import AppKit

let mmToPointsRatio = 72.0 / 25.4

func mmToPoints(_ millimeters: Double) -> CGFloat {
    CGFloat(millimeters * mmToPointsRatio)
}

struct RGBAColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .black
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let accent = RGBAColor(red: 0.17, green: 0.31, blue: 0.88, alpha: 1)
    static let softGray = RGBAColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1)
    static let ink = RGBAColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
}

struct RectMM: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func clamped(maxWidth: Double, maxHeight: Double) -> RectMM {
        let safeWidth = max(5, min(width, maxWidth))
        let safeHeight = max(5, min(height, maxHeight))
        let safeX = min(max(0, x), max(0, maxWidth - safeWidth))
        let safeY = min(max(0, y), max(0, maxHeight - safeHeight))
        return RectMM(x: safeX, y: safeY, width: safeWidth, height: safeHeight)
    }
}

enum LabelShape: String, Codable, CaseIterable, Identifiable {
    case roundedRectangle
    case rectangle
    case capsule
    case circle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .roundedRectangle:
            return "Rounded"
        case .rectangle:
            return "Rectangle"
        case .capsule:
            return "Capsule"
        case .circle:
            return "Circle"
        }
    }
}

enum ElementType: String, Codable, CaseIterable, Identifiable {
    case text
    case rectangle
    case image
    case qrCode
    case code128

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text:
            return "Text"
        case .rectangle:
            return "Shape"
        case .image:
            return "Image"
        case .qrCode:
            return "QR"
        case .code128:
            return "Code128"
        }
    }
}

enum ImageScaleMode: String, Codable, CaseIterable, Identifiable {
    case fit
    case fill

    var id: String { rawValue }
}

enum TextAlignModel: String, Codable, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var alignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }

    var multilineAlignment: TextAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }
}

enum CanvasMode: String, CaseIterable, Identifiable {
    case label
    case page

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum AppAppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct SheetTemplate: Codable, Hashable, Identifiable {
    var id: String
    var name: String
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
    var shape: LabelShape
    var cornerRadiusMM: Double

    func slotFrame(column: Int, row: Int) -> RectMM {
        let x = marginLeftMM + (Double(column) * (labelWidthMM + horizontalGapMM))
        let y = marginTopMM + (Double(row) * (labelHeightMM + verticalGapMM))
        return RectMM(x: x, y: y, width: labelWidthMM, height: labelHeightMM)
    }

    func matches(_ other: SheetTemplate) -> Bool {
        id == other.id ||
        (
            pageWidthMM == other.pageWidthMM &&
            pageHeightMM == other.pageHeightMM &&
            columns == other.columns &&
            rows == other.rows &&
            labelWidthMM == other.labelWidthMM &&
            labelHeightMM == other.labelHeightMM &&
            horizontalGapMM == other.horizontalGapMM &&
            verticalGapMM == other.verticalGapMM &&
            marginLeftMM == other.marginLeftMM &&
            marginTopMM == other.marginTopMM &&
            shape == other.shape &&
            cornerRadiusMM == other.cornerRadiusMM
        )
    }

    static let presets: [SheetTemplate] = [
        SheetTemplate(
            id: "a4-2x5-shipping",
            name: "A4 Shipping 2x5",
            pageWidthMM: 210,
            pageHeightMM: 297,
            columns: 2,
            rows: 5,
            labelWidthMM: 99.1,
            labelHeightMM: 57,
            horizontalGapMM: 2.8,
            verticalGapMM: 2.5,
            marginLeftMM: 4.5,
            marginTopMM: 4.5,
            shape: .roundedRectangle,
            cornerRadiusMM: 2.4
        ),
        SheetTemplate(
            id: "a4-3x8-address",
            name: "A4 Address 3x8",
            pageWidthMM: 210,
            pageHeightMM: 297,
            columns: 3,
            rows: 8,
            labelWidthMM: 63.5,
            labelHeightMM: 33.9,
            horizontalGapMM: 3,
            verticalGapMM: 2.5,
            marginLeftMM: 6.5,
            marginTopMM: 8,
            shape: .roundedRectangle,
            cornerRadiusMM: 1.8
        ),
        SheetTemplate(
            id: "a4-round-4x5",
            name: "A4 Round 4x5",
            pageWidthMM: 210,
            pageHeightMM: 297,
            columns: 4,
            rows: 5,
            labelWidthMM: 42,
            labelHeightMM: 42,
            horizontalGapMM: 6,
            verticalGapMM: 8.5,
            marginLeftMM: 9,
            marginTopMM: 10,
            shape: .circle,
            cornerRadiusMM: 21
        ),
        SheetTemplate(
            id: "roll-100x50",
            name: "Roll 100 x 50",
            pageWidthMM: 100,
            pageHeightMM: 50,
            columns: 1,
            rows: 1,
            labelWidthMM: 100,
            labelHeightMM: 50,
            horizontalGapMM: 0,
            verticalGapMM: 0,
            marginLeftMM: 0,
            marginTopMM: 0,
            shape: .roundedRectangle,
            cornerRadiusMM: 2.5
        )
    ]

    static let customDefault = SheetTemplate(
        id: "custom",
        name: "Custom",
        pageWidthMM: 210,
        pageHeightMM: 297,
        columns: 2,
        rows: 5,
        labelWidthMM: 95,
        labelHeightMM: 55,
        horizontalGapMM: 4,
        verticalGapMM: 4,
        marginLeftMM: 6,
        marginTopMM: 6,
        shape: .roundedRectangle,
        cornerRadiusMM: 2
    )
}

enum SerialMode: String, Codable, CaseIterable, Identifiable {
    case continuous
    case rangedSets

    var id: String { rawValue }

    var label: String {
        switch self {
        case .continuous:
            return "Continuous"
        case .rangedSets:
            return "Range + Sets"
        }
    }
}

struct SerialSettings: Codable, Hashable {
    var mode: SerialMode
    var start: Int
    var step: Int
    var end: Int
    var repeatSets: Int
    var digits: Int
    var prefix: String
    var suffix: String

    var countPerSet: Int {
        guard step > 0, end >= start else { return 0 }
        return ((end - start) / step) + 1
    }

    var totalGeneratedCount: Int {
        guard mode == .rangedSets else { return 0 }
        return countPerSet * max(repeatSets, 1)
    }

    func generatedValue(at index: Int) -> Int? {
        guard mode == .rangedSets else { return nil }
        let countPerSet = countPerSet
        guard countPerSet > 0, index >= 0, index < totalGeneratedCount else { return nil }
        let indexInSet = index % countPerSet
        return start + (indexInSet * step)
    }

    func formatted(_ value: Int) -> String {
        let digits = max(digits, 1)
        let raw = String(format: "%0\(digits)d", value)
        return prefix + raw + suffix
    }

    static let `default` = SerialSettings(
        mode: .rangedSets,
        start: 1,
        step: 1,
        end: 12,
        repeatSets: 1,
        digits: 1,
        prefix: "(",
        suffix: ")"
    )
}

struct DataTable: Codable {
    var headers: [String]
    var rows: [[String: String]]
}

struct PrintAutomationSettings: Codable, Hashable {
    var enabled: Bool
    var wifiService: String
    var printerSSID: String
    var printerPassword: String
    var reconnectToPreviousWiFi: Bool
    var settleSeconds: Double

    static let `default` = PrintAutomationSettings(
        enabled: false,
        wifiService: "Wi-Fi",
        printerSSID: "",
        printerPassword: "",
        reconnectToPreviousWiFi: true,
        settleSeconds: 2.0
    )
}

struct PlacementSettings: Codable, Hashable {
    var selectedSlotIndices: [Int]
    var fillDirection: PlacementFillDirection

    static let `default` = PlacementSettings(selectedSlotIndices: [], fillDirection: .horizontal)
}

enum PlacementFillDirection: String, Codable, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .horizontal:
            return "Horizontal"
        case .vertical:
            return "Vertical"
        }
    }
}

struct MergeContext {
    var row: [String: String]
    var serialValue: Int?
    var rowNumber: Int
    var pageNumber: Int
    var slotNumber: Int
    var isActive: Bool
}

struct LabelElement: Codable, Identifiable, Hashable {
    var id: UUID
    var type: ElementType
    var name: String
    var frame: RectMM
    var rotation: Double
    var opacity: Double
    var content: String
    var fontSize: Double
    var fontName: String
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var textAlignment: TextAlignModel
    var foreground: RGBAColor
    var background: RGBAColor
    var stroke: RGBAColor
    var strokeWidth: Double
    var cornerRadiusMM: Double
    var verticalTextLayout: Bool?
    var richTextRTF: Data?
    var imageData: Data?
    var imageScaleMode: ImageScaleMode

    static func make(_ type: ElementType, index: Int) -> LabelElement {
        switch type {
        case .text:
            return LabelElement(
                id: UUID(),
                type: .text,
                name: "Text \(index)",
                frame: RectMM(x: 10, y: 8 + Double(index * 4), width: 76, height: 12),
                rotation: 0,
                opacity: 1,
                content: index == 1 ? "Product Label" : "Edit this text or use {{Column}}",
                fontSize: index == 1 ? 22 : 12,
                fontName: "Arial",
                isBold: index == 1,
                isItalic: false,
                isUnderline: false,
                textAlignment: .center,
                foreground: .black,
                background: .clear,
                stroke: .clear,
                strokeWidth: 0,
                cornerRadiusMM: 0,
                verticalTextLayout: false,
                richTextRTF: nil,
                imageData: nil,
                imageScaleMode: .fit
            )
        case .rectangle:
            return LabelElement(
                id: UUID(),
                type: .rectangle,
                name: "Shape \(index)",
                frame: RectMM(x: 6, y: 6, width: 87, height: 45),
                rotation: 0,
                opacity: 1,
                content: "",
                fontSize: 12,
                fontName: "SF Pro",
                isBold: false,
                isItalic: false,
                isUnderline: false,
                textAlignment: .center,
                foreground: .clear,
                background: RGBAColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
                stroke: RGBAColor(red: 0.68, green: 0.74, blue: 0.91, alpha: 1),
                strokeWidth: 1,
                cornerRadiusMM: 2.5,
                verticalTextLayout: false,
                richTextRTF: nil,
                imageData: nil,
                imageScaleMode: .fit
            )
        case .image:
            return LabelElement(
                id: UUID(),
                type: .image,
                name: "Image \(index)",
                frame: RectMM(x: 8, y: 8, width: 24, height: 24),
                rotation: 0,
                opacity: 1,
                content: "",
                fontSize: 12,
                fontName: "SF Pro",
                isBold: false,
                isItalic: false,
                isUnderline: false,
                textAlignment: .center,
                foreground: .black,
                background: .softGray,
                stroke: RGBAColor(red: 0.78, green: 0.8, blue: 0.84, alpha: 1),
                strokeWidth: 1,
                cornerRadiusMM: 2,
                verticalTextLayout: false,
                richTextRTF: nil,
                imageData: nil,
                imageScaleMode: .fit
            )
        case .qrCode:
            return LabelElement(
                id: UUID(),
                type: .qrCode,
                name: "QR \(index)",
                frame: RectMM(x: 68, y: 8, width: 22, height: 22),
                rotation: 0,
                opacity: 1,
                content: "https://label.kr",
                fontSize: 12,
                fontName: "SF Pro",
                isBold: false,
                isItalic: false,
                isUnderline: false,
                textAlignment: .center,
                foreground: .black,
                background: .white,
                stroke: RGBAColor(red: 0.75, green: 0.77, blue: 0.82, alpha: 1),
                strokeWidth: 1,
                cornerRadiusMM: 1.2,
                verticalTextLayout: false,
                richTextRTF: nil,
                imageData: nil,
                imageScaleMode: .fit
            )
        case .code128:
            return LabelElement(
                id: UUID(),
                type: .code128,
                name: "Barcode \(index)",
                frame: RectMM(x: 10, y: 33, width: 80, height: 14),
                rotation: 0,
                opacity: 1,
                content: "SKU-0001",
                fontSize: 11,
                fontName: "SF Pro",
                isBold: false,
                isItalic: false,
                isUnderline: false,
                textAlignment: .center,
                foreground: .black,
                background: .white,
                stroke: RGBAColor(red: 0.75, green: 0.77, blue: 0.82, alpha: 1),
                strokeWidth: 1,
                cornerRadiusMM: 1.2,
                verticalTextLayout: false,
                richTextRTF: nil,
                imageData: nil,
                imageScaleMode: .fit
            )
        }
    }
}

struct LabelDocument: Codable {
    var title: String
    var sheet: SheetTemplate
    var elements: [LabelElement]
    var serial: SerialSettings
    var dataTable: DataTable?
    var notes: String
    var formatCode: String?
    var formatFamily: ProductFamily?
    var formatSourceURL: String?
    var formatPDFTemplateURL: String?
    var printAutomation: PrintAutomationSettings
    var placement: PlacementSettings

    var totalSlotCount: Int {
        max(1, sheet.columns * sheet.rows)
    }

    var activeSlotIndices: [Int] {
        let indices = placement.selectedSlotIndices
            .filter { $0 >= 0 && $0 < totalSlotCount }
        let normalized = indices.isEmpty ? Array(0..<totalSlotCount) : Array(Set(indices))
        switch placement.fillDirection {
        case .horizontal:
            return normalized.sorted()
        case .vertical:
            return normalized.sorted { lhs, rhs in
                let leftColumn = lhs % sheet.columns
                let rightColumn = rhs % sheet.columns
                if leftColumn == rightColumn {
                    return lhs / sheet.columns < rhs / sheet.columns
                }
                return leftColumn < rightColumn
            }
        }
    }

    var pageCapacity: Int {
        max(1, activeSlotIndices.count)
    }

    var mergeRowCount: Int {
        if let dataTable, !dataTable.rows.isEmpty {
            return dataTable.rows.count
        }
        return serial.totalGeneratedCount
    }

    var hasFiniteMergeRows: Bool {
        mergeRowCount > 0
    }

    var pageCount: Int {
        let mergeRowCount = mergeRowCount
        guard mergeRowCount > 0 else { return 1 }
        return max(1, Int(ceil(Double(mergeRowCount) / Double(pageCapacity))))
    }

    func visiblePreviewSlotIndices(pageIndex: Int) -> [Int] {
        if !hasFiniteMergeRows {
            return activeSlotIndices
        }

        let visible = activeSlotIndices.filter { slotIndex in
            mergeContext(slotIndex: slotIndex, pageIndex: pageIndex).isActive
        }
        return visible.isEmpty ? Array(activeSlotIndices.prefix(1)) : visible
    }

    func bounds(for slotIndices: [Int]) -> RectMM {
        let indices = slotIndices.isEmpty ? activeSlotIndices : slotIndices
        guard let first = indices.first else {
            return RectMM(x: 0, y: 0, width: sheet.pageWidthMM, height: sheet.pageHeightMM)
        }

        let firstRow = first / sheet.columns
        let firstColumn = first % sheet.columns
        let firstFrame = sheet.slotFrame(column: firstColumn, row: firstRow)

        var minX = firstFrame.x
        var minY = firstFrame.y
        var maxX = firstFrame.x + firstFrame.width
        var maxY = firstFrame.y + firstFrame.height

        for index in indices.dropFirst() {
            let row = index / sheet.columns
            let column = index % sheet.columns
            let frame = sheet.slotFrame(column: column, row: row)
            minX = min(minX, frame.x)
            minY = min(minY, frame.y)
            maxX = max(maxX, frame.x + frame.width)
            maxY = max(maxY, frame.y + frame.height)
        }

        return RectMM(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func coordinate(for slotIndex: Int) -> (row: Int, column: Int) {
        let row = (slotIndex / sheet.columns) + 1
        let column = (slotIndex % sheet.columns) + 1
        return (row, column)
    }

    func coordinateLabel(for slotIndex: Int) -> String {
        let coordinate = coordinate(for: slotIndex)
        return "(\(coordinate.row),\(coordinate.column))"
    }

    func mergeContext(slotIndex: Int, pageIndex: Int) -> MergeContext {
        guard let logicalSlot = activeSlotIndices.firstIndex(of: slotIndex) else {
            return MergeContext(
                row: [:],
                serialValue: nil,
                rowNumber: 0,
                pageNumber: pageIndex + 1,
                slotNumber: slotIndex + 1,
                isActive: false
            )
        }

        let globalIndex = (pageIndex * pageCapacity) + logicalSlot
        let tableRows = dataTable?.rows ?? []
        let hasCSVRows = !tableRows.isEmpty

        let isActive: Bool
        let rowData: [String: String]
        let serialValue: Int?

        if hasCSVRows {
            isActive = globalIndex < tableRows.count
            rowData = isActive ? tableRows[globalIndex] : [:]
            serialValue = isActive ? (serial.start + (globalIndex * serial.step)) : nil
        } else if serial.mode == .rangedSets {
            serialValue = serial.generatedValue(at: globalIndex)
            isActive = serialValue != nil
            if let serialValue {
                let countPerSet = max(serial.countPerSet, 1)
                let setNumber = (globalIndex / countPerSet) + 1
                let indexInSet = (globalIndex % countPerSet) + 1
                rowData = [
                    "serial": serial.formatted(serialValue),
                    "serial_raw": "\(serialValue)",
                    "set": "\(setNumber)",
                    "index_in_set": "\(indexInSet)"
                ]
            } else {
                rowData = [:]
            }
        } else {
            isActive = true
            rowData = [:]
            serialValue = serial.start + (globalIndex * serial.step)
        }

        return MergeContext(
            row: rowData,
            serialValue: serialValue,
            rowNumber: globalIndex + 1,
            pageNumber: pageIndex + 1,
            slotNumber: slotIndex + 1,
            isActive: isActive
        )
    }

    mutating func clampElementsToSheet() {
        elements = elements.map { element in
            var copy = element
            copy.frame = element.frame.clamped(
                maxWidth: sheet.labelWidthMM,
                maxHeight: sheet.labelHeightMM
            )
            return copy
        }
    }

    static let starter = LabelDocument(
        title: "iLabel2Mac Demo",
        sheet: SheetTemplate.presets[0],
        elements: [
            .make(.rectangle, index: 1),
            .make(.text, index: 1),
            .make(.text, index: 2),
            .make(.qrCode, index: 1),
            .make(.code128, index: 1)
        ],
        serial: .default,
        dataTable: nil,
        notes: "Use {{Column}}, {{serial}}, {{page}}, {{slot}}, {{row}}, {{date}} placeholders.",
        formatCode: nil,
        formatFamily: nil,
        formatSourceURL: nil,
        formatPDFTemplateURL: nil,
        printAutomation: .default,
        placement: .default
    )
}
