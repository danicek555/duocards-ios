import Foundation
import XCTest
@testable import DuoCards

final class SetEditorTests: XCTestCase {
    func testRejectsBlankSetName() {
        let form = SetEditorForm(
            name: "   ",
            words: [validCard()]
        )

        assertValidationError(.emptyName, for: form)
    }

    func testRejectsIncompleteCardAndReportsPosition() {
        let form = SetEditorForm(
            name: "Základy",
            words: [
                validCard(),
                EditableFlashcard(word: "", translation: "ahoj")
            ]
        )

        assertValidationError(.incompleteWord(index: 2), for: form)
    }

    func testRejectsMoreThanOneHundredCards() {
        let cards = (0..<101).map { index in
            EditableFlashcard(
                word: "word \(index)",
                translation: "překlad \(index)"
            )
        }
        let form = SetEditorForm(name: "Velká sada", words: cards)

        assertValidationError(.invalidWordCount, for: form)
    }

    func testRejectsMoreThanFiveTags() {
        let form = SetEditorForm(
            name: "Tagy",
            tags: ["1", "2", "3", "4", "5", "6"],
            words: [validCard()]
        )

        assertValidationError(.tooManyTags, for: form)
    }

    func testValidationTrimsValuesAndPreservesServerWordID() throws {
        let form = SetEditorForm(
            name: "  Francouzština  ",
            fromLanguage: " French ",
            toLanguage: "  ",
            tags: [" Travel ", "travel", " A1 "],
            words: [
                EditableFlashcard(
                    serverID: 17,
                    word: " bonjour ",
                    translation: " ahoj ",
                    difficulty: 2,
                    pronunciation: " /bɔ̃.ʒuʁ/ "
                )
            ]
        )

        let payload = try form.validatedPayload()

        XCTAssertEqual(payload.name, "Francouzština")
        XCTAssertEqual(payload.fromLanguage, "French")
        XCTAssertNil(payload.toLanguage)
        XCTAssertEqual(payload.tags, ["Travel", "A1"])
        XCTAssertEqual(
            payload.words,
            [
                FlashcardWordPayload(
                    id: 17,
                    word: "bonjour",
                    translation: "ahoj",
                    difficulty: 2,
                    pronunciation: "/bɔ̃.ʒuʁ/"
                )
            ]
        )
    }

    func testPayloadEncodesBackendMutationShape() throws {
        let payload = FlashcardSetPayload(
            name: "English",
            fromLanguage: "English",
            toLanguage: nil,
            tags: ["A1"],
            words: [
                FlashcardWordPayload(
                    id: nil,
                    word: "hello",
                    translation: "ahoj",
                    difficulty: 1,
                    pronunciation: nil
                )
            ]
        )

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let words = try XCTUnwrap(object["words"] as? [[String: Any]])
        let word = try XCTUnwrap(words.first)

        XCTAssertEqual(object["name"] as? String, "English")
        XCTAssertEqual(object["fromLanguage"] as? String, "English")
        XCTAssertNil(object["toLanguage"])
        XCTAssertEqual(object["tags"] as? [String], ["A1"])
        XCTAssertEqual(word["word"] as? String, "hello")
        XCTAssertEqual(word["translation"] as? String, "ahoj")
        XCTAssertEqual(word["difficulty"] as? Int, 1)
        XCTAssertNil(word["id"])
        XCTAssertNil(word["pronunciation"])
    }

    private func validCard() -> EditableFlashcard {
        EditableFlashcard(word: "hello", translation: "ahoj")
    }

    private func assertValidationError(
        _ expected: SetEditorValidationError,
        for form: SetEditorForm,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try form.validatedPayload(),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? SetEditorValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
