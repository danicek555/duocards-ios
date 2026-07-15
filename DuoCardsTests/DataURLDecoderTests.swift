import Foundation
import XCTest
@testable import DuoCards

final class DataURLDecoderTests: XCTestCase {
    func testDecodesBase64PayloadAndMIMEType() throws {
        let decoded = try DataURLDecoder.decode(
            "data:text/plain;base64,SGVsbG8sIER1b0NhcmRzIQ=="
        )

        XCTAssertEqual(decoded.mimeType, "text/plain")
        XCTAssertEqual(String(data: decoded.data, encoding: .utf8), "Hello, DuoCards!")
    }

    func testDecodesPercentEncodedPayloadWithDefaultMIMEType() throws {
        let decoded = try DataURLDecoder.decode("data:,Ahoj%20sv%C4%9Bte")

        XCTAssertEqual(decoded.mimeType, "text/plain")
        XCTAssertEqual(String(data: decoded.data, encoding: .utf8), "Ahoj světe")
    }

    func testRejectsValueWithoutDataURLPrefix() {
        XCTAssertThrowsError(try DataURLDecoder.decode("https://duocards.xyz/image.png")) { error in
            XCTAssertEqual(error as? DataURLDecodingError, .invalidPrefix)
        }
    }
}
