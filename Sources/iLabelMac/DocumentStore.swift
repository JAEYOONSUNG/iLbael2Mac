import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let defaultOfficialFormatCode = "680"
private let cachedPrintAutomationKey = "iLabel2Mac.cachedPrintAutomation"
private let cachedQuickTextPresetsKey = "iLabel2Mac.cachedQuickTextPresets"
private let cachedAppearanceModeKey = "iLabel2Mac.cachedAppearanceMode"
let quickTextInsertNotification = Notification.Name("iLabel2Mac.quickTextInsert")
let textStyleActionNotification = Notification.Name("iLabel2Mac.textStyleAction")

enum TextStyleAction: String {
    case bold
    case italic
    case underline
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published var document: LabelDocument = .starter
    @Published var previewDocument: LabelDocument = .starter
    @Published var selectedElementID: UUID?
    @Published var editingElementID: UUID?
    @Published var canvasMode: CanvasMode = .label
    @Published var currentPageIndex = 0
    @Published var statusMessage = "Ready"
    @Published var projectURL: URL?
    @Published var formatSearchText = ""
    @Published var selectedFamilyFilter: ProductFamily?
    @Published var quickTextPresets: [String] = []
    @Published var newQuickTextPreset = ""
    @Published var currentWiFiSSID = ""
    @Published var wifiTestStatus = "Not tested"
    @Published var appearanceMode: AppAppearanceMode = .system {
        didSet { persistAppearanceMode() }
    }

    let officialFormats: [OfficialFormatDefinition]
    private var previewRefreshWorkItem: DispatchWorkItem?

    init() {
        officialFormats = OfficialFormatCatalog.load()
        if let defaultFormat = officialFormats.first(where: { $0.code == defaultOfficialFormatCode }) ?? officialFormats.first {
            document.sheet = defaultFormat.sheetTemplate
            document.formatCode = defaultFormat.code
            document.formatFamily = defaultFormat.family
            document.formatSourceURL = defaultFormat.detailURL
            document.formatPDFTemplateURL = defaultFormat.pdfTemplateURL
            document.title = defaultFormat.code
            document.elements = []
        }
        document.printAutomation = loadCachedPrintAutomation()
        quickTextPresets = loadCachedQuickTextPresets()
        appearanceMode = loadAppearanceMode()
        previewDocument = document
        selectedElementID = document.elements.first?.id
        editingElementID = nil
        refreshCurrentWiFiSSID()
    }

    var selectedElement: LabelElement? {
        guard let selectedElementID else { return nil }
        return document.elements.first(where: { $0.id == selectedElementID })
    }

    var editingElement: LabelElement? {
        guard let editingElementID else { return nil }
        return document.elements.first(where: { $0.id == editingElementID })
    }

    var currentFormat: OfficialFormatDefinition? {
        guard let code = document.formatCode else { return nil }
        return officialFormats.first(where: { $0.code == code })
    }

    var filteredFormats: [OfficialFormatDefinition] {
        let query = formatSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return officialFormats.filter { format in
            let familyMatches = selectedFamilyFilter == nil || format.family == selectedFamilyFilter
            guard familyMatches else { return false }

            guard !query.isEmpty else { return true }
            let haystack = [
                format.code,
                format.name,
                format.family.label,
                format.sizeSummary,
                format.officialType
            ].joined(separator: " ").lowercased()
            return haystack.contains(query.lowercased())
        }
    }

    func updateSheet(_ edit: (inout SheetTemplate) -> Void) {
        edit(&document.sheet)
        document.clampElementsToSheet()
        currentPageIndex = min(currentPageIndex, max(0, document.pageCount - 1))
        schedulePreviewRefresh()
    }

    func updateDocument(_ edit: (inout LabelDocument) -> Void) {
        edit(&document)
        document.clampElementsToSheet()
        persistPrintAutomationCache(document.printAutomation)
        refreshCurrentWiFiSSID()
        currentPageIndex = min(currentPageIndex, max(0, document.pageCount - 1))
        schedulePreviewRefresh()
    }

    func updateSelected(_ edit: (inout LabelElement) -> Void) {
        guard let selectedElementID else {
            return
        }
        updateElement(id: selectedElementID, edit)
    }

    func updateElement(id: UUID, _ edit: (inout LabelElement) -> Void) {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else {
            return
        }
        edit(&document.elements[index])
        document.elements[index].frame = document.elements[index].frame.clamped(
            maxWidth: document.sheet.labelWidthMM,
            maxHeight: document.sheet.labelHeightMM
        )
        schedulePreviewRefresh()
    }

    func selectElement(_ id: UUID?, beginEditing: Bool = false) {
        selectedElementID = id
        if beginEditing,
           let id,
           let element = document.elements.first(where: { $0.id == id }),
           element.type == .text {
            editingElementID = id
            statusMessage = "Editing text"
        } else if editingElementID != id {
            editingElementID = nil
        }
    }

    func finishInlineEditing() {
        editingElementID = nil
        schedulePreviewRefresh(immediate: true)
    }

    func insertQuickTextPreset(_ preset: String) {
        guard !preset.isEmpty else { return }
        NotificationCenter.default.post(name: quickTextInsertNotification, object: preset)
        statusMessage = "Inserted preset: \(preset)"
    }

    func addQuickTextPreset() {
        let trimmed = newQuickTextPreset.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !quickTextPresets.contains(trimmed) else {
            newQuickTextPreset = ""
            return
        }
        quickTextPresets.append(trimmed)
        quickTextPresets.sort()
        persistQuickTextPresets()
        newQuickTextPreset = ""
        statusMessage = "Saved preset: \(trimmed)"
    }

    func saveSelectedContentAsPreset() {
        guard let selectedElement, selectedElement.type == .text else { return }
        let trimmed = selectedElement.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newQuickTextPreset = trimmed
        addQuickTextPreset()
    }

    func removeQuickTextPreset(_ preset: String) {
        quickTextPresets.removeAll { $0 == preset }
        persistQuickTextPresets()
        statusMessage = "Removed preset: \(preset)"
    }

    func savePrintAutomationSettings() {
        persistPrintAutomationCache(document.printAutomation)
        refreshCurrentWiFiSSID()
        wifiTestStatus = "Saved"
        statusMessage = "Saved Wi-Fi print settings"
    }

    func testPrintAutomationConnection() {
        let settings = document.printAutomation
        wifiTestStatus = "Testing..."
        Task {
            do {
                let session = try await WiFiPrintAutomation.prepare(settings: settings)
                await MainActor.run {
                    refreshCurrentWiFiSSID()
                    wifiTestStatus = settings.enabled ? "Connected to \(currentWiFiSSID)" : "Wi-Fi print disabled"
                    statusMessage = settings.enabled ? "Connected to printer Wi-Fi" : "Wi-Fi print is disabled"
                }
                if let session, settings.reconnectToPreviousWiFi {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    try? await session.restore()
                    await MainActor.run {
                        refreshCurrentWiFiSSID()
                        wifiTestStatus = "Restored to \(currentWiFiSSID)"
                        statusMessage = "Wi-Fi test finished and restored previous network"
                    }
                }
            } catch {
                await MainActor.run {
                    refreshCurrentWiFiSSID()
                    wifiTestStatus = "Failed: \(error.localizedDescription)"
                    statusMessage = "Wi-Fi test failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func autofillPrintAutomationSettings() {
        updateDocument { document in
            document.printAutomation.wifiService = "Wi-Fi"
            if let detected = WiFiPrintAutomation.autoDetectedPrinterSSID() {
                document.printAutomation.printerSSID = detected
            }
        }
        refreshCurrentWiFiSSID()
        wifiTestStatus = document.printAutomation.printerSSID.isEmpty ? "No printer SSID auto-detected" : "Auto-filled \(document.printAutomation.printerSSID)"
        statusMessage = wifiTestStatus
    }

    func activatePrimaryTextElement() {
        if let selectedElement, selectedElement.type == .text {
            selectElement(selectedElement.id, beginEditing: true)
            return
        }

        if let firstText = document.elements.first(where: { $0.type == .text }) {
            selectElement(firstText.id, beginEditing: true)
            return
        }

        addElement(.text)
    }

    func applyTextStyleAction(_ action: TextStyleAction) {
        if editingElementID != nil {
            NotificationCenter.default.post(name: textStyleActionNotification, object: action)
            return
        }

        guard let selectedElement, selectedElement.type == .text else { return }
        updateSelected { element in
            switch action {
            case .bold:
                element.isBold.toggle()
            case .italic:
                element.isItalic.toggle()
            case .underline:
                element.isUnderline.toggle()
            }
        }
    }

    func applySelectedTextOrientation(vertical: Bool) {
        guard let selectedElement, selectedElement.type == .text else { return }
        updateSelected { element in
            if vertical {
                let widthFactor: Double
                let heightFactor: Double
                switch document.sheet.shape {
                case .circle:
                    widthFactor = 0.30
                    heightFactor = 0.88
                case .capsule:
                    widthFactor = 0.22
                    heightFactor = 0.82
                case .rectangle, .roundedRectangle:
                    widthFactor = 0.28
                    heightFactor = 0.84
                }

                let targetWidth = max(4.5, document.sheet.labelWidthMM * widthFactor)
                let targetHeight = max(10, document.sheet.labelHeightMM * heightFactor)
                element.frame.width = targetWidth
                element.frame.height = targetHeight
                element.frame.x = max(0, (document.sheet.labelWidthMM - targetWidth) / 2)
                element.frame.y = max(0, (document.sheet.labelHeightMM - targetHeight) / 2)
            }

            element.rotation = 0
            element.verticalTextLayout = vertical
            element.textAlignment = .center
        }
        statusMessage = vertical ? "Applied vertical stacked text layout" : "Applied horizontal text layout"
    }

    func selectPlacementStart(at slotIndex: Int) {
        let total = document.totalSlotCount
        guard slotIndex >= 0, slotIndex < total else { return }
        updateDocument { document in
            document.placement.selectedSlotIndices = Array(slotIndex..<total)
        }
        statusMessage = "Placement starts at \(document.coordinateLabel(for: slotIndex))"
        schedulePreviewRefresh(immediate: true)
    }

    func selectPlacementRect(from startSlot: Int, to endSlot: Int) {
        let columns = document.sheet.columns
        let rows = document.sheet.rows
        guard columns > 0, rows > 0 else { return }

        let startRow = startSlot / columns
        let startColumn = startSlot % columns
        let endRow = endSlot / columns
        let endColumn = endSlot % columns

        let rowRange = min(startRow, endRow)...max(startRow, endRow)
        let columnRange = min(startColumn, endColumn)...max(startColumn, endColumn)

        var indices: [Int] = []
        for row in rowRange {
            for column in columnRange {
                indices.append((row * columns) + column)
            }
        }

        updateDocument { document in
            document.placement.selectedSlotIndices = indices
        }
        if let first = indices.first, let last = indices.last {
            statusMessage = "Selected \(indices.count) slot(s): \(document.coordinateLabel(for: first)) to \(document.coordinateLabel(for: last))"
        } else {
            statusMessage = "Selected \(indices.count) slot(s) for placement"
        }
        schedulePreviewRefresh(immediate: true)
    }

    func clearPlacementSelection() {
        updateDocument { document in
            document.placement.selectedSlotIndices = []
        }
        statusMessage = "Placement reset to full page"
        schedulePreviewRefresh(immediate: true)
    }

    func newDocument() {
        document = .starter
        document.printAutomation = loadCachedPrintAutomation()
        if let defaultFormat = officialFormats.first(where: { $0.code == defaultOfficialFormatCode }) ?? officialFormats.first {
            applyOfficialFormat(defaultFormat, updateTitle: true)
        }
        currentPageIndex = 0
        projectURL = nil
        selectedElementID = document.elements.first?.id
        editingElementID = nil
        schedulePreviewRefresh(immediate: true)
        statusMessage = "Started a new label project"
    }

    func applyPreset(id: String) {
        guard let preset = SheetTemplate.presets.first(where: { $0.id == id }) else {
            return
        }
        updateSheet { sheet in
            sheet = preset
        }
        document.formatCode = nil
        document.formatFamily = nil
        document.formatSourceURL = nil
        document.formatPDFTemplateURL = nil
        schedulePreviewRefresh(immediate: true)
        statusMessage = "Applied preset: \(preset.name)"
    }

    func applyOfficialFormat(code: String) {
        guard let format = officialFormats.first(where: { $0.code == code }) else {
            return
        }
        applyOfficialFormat(format, updateTitle: false)
    }

    func applyOfficialFormat(_ format: OfficialFormatDefinition, updateTitle: Bool) {
        let shouldResetToBlankCanvas = document.elements.isEmpty || document.elements == LabelDocument.starter.elements
        updateDocument { document in
            document.sheet = format.sheetTemplate
            document.formatCode = format.code
            document.formatFamily = format.family
            document.formatSourceURL = format.detailURL
            document.formatPDFTemplateURL = format.pdfTemplateURL
            if shouldResetToBlankCanvas {
                document.elements = []
            }
            if updateTitle || document.title == "iLabel2Mac Demo" || document.title.isEmpty {
                document.title = format.code
            }
        }
        if shouldResetToBlankCanvas {
            selectedElementID = nil
        }
        editingElementID = nil
        schedulePreviewRefresh(immediate: true)
        statusMessage = "Applied official format: \(format.code)"
    }

    func addElement(_ type: ElementType) {
        let count = document.elements.filter { $0.type == type }.count + 1
        let element: LabelElement
        switch type {
        case .text:
            element = makeCenteredTextElement(index: count)
        default:
            element = LabelElement.make(type, index: count)
        }
        document.elements.append(element)
        selectedElementID = element.id
        editingElementID = type == .text ? element.id : nil
        schedulePreviewRefresh(immediate: true)
        statusMessage = "Added \(type.label)"
    }

    private func makeCenteredTextElement(index: Int) -> LabelElement {
        var element = LabelElement.make(.text, index: index)

        let elementWidth: Double
        let elementHeight: Double
        switch document.sheet.shape {
        case .circle:
            elementWidth = max(8, document.sheet.labelWidthMM * 0.92)
            elementHeight = max(8, document.sheet.labelHeightMM * 0.92)
        case .capsule:
            elementWidth = max(10, document.sheet.labelWidthMM * 0.90)
            elementHeight = max(8, document.sheet.labelHeightMM * 0.82)
        case .rectangle, .roundedRectangle:
            elementWidth = max(10, document.sheet.labelWidthMM * 0.90)
            elementHeight = max(8, document.sheet.labelHeightMM * 0.78)
        }
        let centeredX = max(0, (document.sheet.labelWidthMM - elementWidth) / 2)
        let verticalBias: Double = (document.formatCode == "680" && document.sheet.shape == .circle) ? -0.12 : 0
        let centeredY = max(0, (document.sheet.labelHeightMM - elementHeight) / 2 + verticalBias)

        element.frame = RectMM(
            x: centeredX,
            y: centeredY,
            width: elementWidth,
            height: elementHeight
        )
        element.content = document.serial.mode == .rangedSets ? "{{serial}}\n{{date}}" : "{{date}}"
        element.fontName = "Arial"
        element.fontSize = 3.5
        element.isBold = false
        element.isItalic = false
        element.isUnderline = false
        element.textAlignment = .center
        element.foreground = .black
        element.background = .clear
        element.stroke = .clear
        element.strokeWidth = 0
        element.cornerRadiusMM = 0

        return element
    }

    func duplicateSelected() {
        guard var copy = selectedElement else { return }
        copy.id = UUID()
        copy.name += " Copy"
        copy.frame.x += 3
        copy.frame.y += 3
        copy.frame = copy.frame.clamped(maxWidth: document.sheet.labelWidthMM, maxHeight: document.sheet.labelHeightMM)
        document.elements.append(copy)
        selectedElementID = copy.id
        editingElementID = nil
        schedulePreviewRefresh(immediate: true)
        statusMessage = "Duplicated \(copy.type.label.lowercased())"
    }

    func deleteSelected() {
        guard let selectedElementID, let index = document.elements.firstIndex(where: { $0.id == selectedElementID }) else {
            return
        }

        let removed = document.elements.remove(at: index)
        self.selectedElementID = document.elements.last?.id
        if editingElementID == removed.id {
            editingElementID = nil
        }
        schedulePreviewRefresh(immediate: true)
        statusMessage = "Deleted \(removed.name)"
    }

    func movePage(delta: Int) {
        currentPageIndex = min(max(0, currentPageIndex + delta), document.pageCount - 1)
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode(LabelDocument.self, from: data)
            document = loaded
            document.clampElementsToSheet()
            projectURL = url
            selectedElementID = document.elements.first?.id
            editingElementID = nil
            currentPageIndex = 0
            schedulePreviewRefresh(immediate: true)
            statusMessage = "Opened \(url.lastPathComponent)"
        } catch {
            statusMessage = "Open failed: \(error.localizedDescription)"
        }
    }

    func saveProject() {
        do {
            let data = try JSONEncoder.pretty.encode(document)
            let targetURL = try saveURL(
                existingURL: projectURL,
                suggestedName: "\(document.title.replacingOccurrences(of: " ", with: "-")).ilabelmac.json",
                allowedTypes: [.json]
            )
            try data.write(to: targetURL, options: .atomic)
            projectURL = targetURL
            statusMessage = "Saved \(targetURL.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let table = try CSVParser.parse(url: url)
            document.dataTable = table
            currentPageIndex = 0
            schedulePreviewRefresh(immediate: true)
            statusMessage = "Loaded \(table.rows.count) data rows from \(url.lastPathComponent)"
        } catch {
            statusMessage = "CSV import failed: \(error.localizedDescription)"
        }
    }

    func pickImageForSelected() {
        guard let selected = selectedElement, selected.type == .image else {
            statusMessage = "Select an image element first"
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            updateSelected { element in
                element.imageData = data
                if element.name == selected.name {
                    element.name = url.deletingPathExtension().lastPathComponent
                }
            }
            statusMessage = "Placed image: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Image import failed: \(error.localizedDescription)"
        }
    }

    func exportPDF() {
        do {
            let renderDocument = prepareRenderableDocument()
            let data = PageRenderer.pdfData(document: renderDocument, pageIndex: currentPageIndex)
            let url = try saveURL(
                existingURL: nil,
                suggestedName: "\(renderDocument.title.replacingOccurrences(of: " ", with: "-"))-page-\(currentPageIndex + 1).pdf",
                allowedTypes: [.pdf]
            )
            try data.write(to: url, options: .atomic)
            statusMessage = "Exported PDF: \(url.lastPathComponent)"
        } catch {
            statusMessage = "PDF export failed: \(error.localizedDescription)"
        }
    }

    func exportPNG() {
        do {
            let renderDocument = prepareRenderableDocument()
            guard let data = PageRenderer.pngData(document: renderDocument, pageIndex: currentPageIndex) else {
                statusMessage = "PNG export failed"
                return
            }
            let url = try saveURL(
                existingURL: nil,
                suggestedName: "\(renderDocument.title.replacingOccurrences(of: " ", with: "-"))-page-\(currentPageIndex + 1).png",
                allowedTypes: [.png]
            )
            try data.write(to: url, options: .atomic)
            statusMessage = "Exported PNG: \(url.lastPathComponent)"
        } catch {
            statusMessage = "PNG export failed: \(error.localizedDescription)"
        }
    }

    func printCurrentPage() {
        let snapshot = prepareRenderableDocument()
        let pageIndex = currentPageIndex
        let settings = document.printAutomation

        Task {
            do {
                await MainActor.run {
                    if settings.enabled {
                        wifiTestStatus = "Connecting to \(settings.printerSSID)..."
                        statusMessage = "Connecting to printer Wi-Fi..."
                    } else {
                        wifiTestStatus = "Wi-Fi print disabled"
                    }
                }

                let session = try await WiFiPrintAutomation.prepare(settings: settings)
                if session != nil {
                    await MainActor.run {
                        refreshCurrentWiFiSSID()
                        wifiTestStatus = "Connected to \(currentWiFiSSID)"
                        statusMessage = "Connected to printer Wi-Fi"
                    }
                    let nanoseconds = UInt64(max(0, settings.settleSeconds) * 1_000_000_000)
                    if nanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: nanoseconds)
                    }
                }

                await MainActor.run {
                    PageRenderer.print(document: snapshot, pageIndex: pageIndex)
                }

                if let session {
                    await MainActor.run {
                        wifiTestStatus = "Restoring previous Wi-Fi..."
                        statusMessage = "Restoring previous Wi-Fi..."
                    }
                    try? await session.restore()
                    await MainActor.run {
                        refreshCurrentWiFiSSID()
                        wifiTestStatus = "Restored to \(currentWiFiSSID)"
                        statusMessage = "Returned to previous Wi-Fi after printing"
                    }
                } else {
                    await MainActor.run {
                        refreshCurrentWiFiSSID()
                        wifiTestStatus = "Printed without Wi-Fi switching"
                        statusMessage = "Sent page \(pageIndex + 1) to print dialog"
                    }
                }
            } catch {
                await MainActor.run {
                    refreshCurrentWiFiSSID()
                    wifiTestStatus = "Print Wi-Fi failed: \(error.localizedDescription)"
                    statusMessage = "Print automation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func prepareRenderableDocument() -> LabelDocument {
        NSApp.keyWindow?.makeFirstResponder(nil)
        finishInlineEditing()
        schedulePreviewRefresh(immediate: true)
        return document
    }

    private func schedulePreviewRefresh(immediate: Bool = false) {
        previewRefreshWorkItem?.cancel()

        if immediate {
            previewDocument = document
            return
        }

        let snapshot = document
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.previewDocument = snapshot
            }
        }
        previewRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func loadCachedPrintAutomation() -> PrintAutomationSettings {
        guard
            let data = UserDefaults.standard.data(forKey: cachedPrintAutomationKey),
            let settings = try? JSONDecoder().decode(PrintAutomationSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    private func persistPrintAutomationCache(_ settings: PrintAutomationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: cachedPrintAutomationKey)
    }

    private func loadCachedQuickTextPresets() -> [String] {
        if let items = UserDefaults.standard.stringArray(forKey: cachedQuickTextPresetsKey), !items.isEmpty {
            return items
        }
        return ["DH5a", "TOP10", "JM110", "BL21(DE3)", "Stbl3"]
    }

    private func persistQuickTextPresets() {
        UserDefaults.standard.set(quickTextPresets, forKey: cachedQuickTextPresetsKey)
    }

    private func loadAppearanceMode() -> AppAppearanceMode {
        guard let raw = UserDefaults.standard.string(forKey: cachedAppearanceModeKey),
              let mode = AppAppearanceMode(rawValue: raw) else {
            return .system
        }
        return mode
    }

    private func persistAppearanceMode() {
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: cachedAppearanceModeKey)
    }

    private func refreshCurrentWiFiSSID() {
        currentWiFiSSID = WiFiPrintAutomation.currentSSID(service: document.printAutomation.wifiService) ?? "Unknown"
    }

    private func saveURL(existingURL: URL?, suggestedName: String, allowedTypes: [UTType]) throws -> URL {
        if let existingURL {
            return existingURL
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = allowedTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            throw CocoaError(.userCancelled)
        }

        return url
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
