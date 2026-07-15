import Foundation
import XCTest
@testable import DuoCards

final class ModelDecodingTests: XCTestCase {
    func testDecodesV1NestedErrorEnvelope() throws {
        let json = #"""
        {
          "error": {
            "code": "INVALID_CREDENTIALS",
            "message": "E-mail nebo heslo není správné."
          }
        }
        """#.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(APIErrorEnvelope.self, from: json)

        XCTAssertEqual(envelope.code, "INVALID_CREDENTIALS")
        XCTAssertEqual(envelope.displayMessage, "E-mail nebo heslo není správné.")
    }

    func testDecodesSetSummaryUsingServerWordCount() throws {
        let json = #"""
        {
          "id": 42,
          "name": "Španělština na cesty",
          "fromLanguage": "cs",
          "toLanguage": "es",
          "tags": ["travel", "A1"],
          "isPublic": true,
          "wordCount": 18
        }
        """#.data(using: .utf8)!

        let set = try JSONDecoder().decode(FlashcardSet.self, from: json)

        XCTAssertEqual(set.id, 42)
        XCTAssertEqual(set.name, "Španělština na cesty")
        XCTAssertEqual(set.wordCount, 18)
        XCTAssertEqual(set.tags, ["travel", "A1"])
        XCTAssertTrue(set.isPublic)
        XCTAssertTrue(set.words.isEmpty)
    }

    func testDecodesSetDetailAndToleratesMissingWordDefaults() throws {
        let json = #"""
        {
          "id": 7,
          "name": "Základy",
          "words": [
            {
              "id": 11,
              "word": "hello",
              "translation": "ahoj",
              "difficulty": 2,
              "pronunciation": "həˈləʊ",
              "image": {
                "id": 3,
                "dataUrl": "data:image/png;base64,aGVsbG8=",
                "mimeType": "image/png"
              }
            },
            {
              "word": "goodbye",
              "translation": "na shledanou"
            }
          ]
        }
        """#.data(using: .utf8)!

        let set = try JSONDecoder().decode(FlashcardSet.self, from: json)

        XCTAssertEqual(set.wordCount, 2)
        XCTAssertEqual(set.words[0].pronunciation, "həˈləʊ")
        XCTAssertEqual(set.words[0].imageDataURL, "data:image/png;base64,aGVsbG8=")
        XCTAssertEqual(set.words[1].id, 0)
        XCTAssertEqual(set.words[1].difficulty, 1)
    }
}
