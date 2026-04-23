import AppKit
import XCTest
@testable import iLabelMac

final class RichTextScalingTests: XCTestCase {
    func testRichTextRendererNormalizesDisplayScaledFontsForPrint() throws {
        var element = LabelElement.make(.text, index: 1)
        element.content = "{{serial}}"
        element.fontSize = 3.5
        element.fontName = "Arial"
        element.foreground = .black
        element.richTextRTF = try richTextData(string: "{{serial}}", pointSize: 96)

        let rendered = TextLayoutRenderer.attributedString(
            for: element,
            context: MergeContext(
                row: [:],
                serialValue: 7,
                rowNumber: 1,
                pageNumber: 1,
                slotNumber: 1,
                isActive: true
            ),
            serialSettings: .default
        )

        XCTAssertEqual(rendered.string, "(7)")
        let font = try XCTUnwrap(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(font.pointSize, CGFloat(element.fontSize), accuracy: 0.01)
    }

    private func richTextData(string: String, pointSize: CGFloat) throws -> Data {
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.systemFont(ofSize: pointSize),
                .foregroundColor: NSColor.black
            ]
        )
        return try XCTUnwrap(attributed.rtf(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ))
    }
}
