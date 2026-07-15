import Foundation
import UIKit

struct DecodedDataURL: Equatable, Sendable {
    let mimeType: String
    let data: Data
}

enum DataURLDecodingError: LocalizedError, Sendable, Equatable {
    case invalidPrefix
    case missingSeparator
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidPrefix:
            "Hodnota není data URL."
        case .missingSeparator:
            "Data URL nemá oddělenou hlavičku a obsah."
        case .invalidPayload:
            "Obsah data URL nelze dekódovat."
        }
    }
}

enum DataURLDecoder {
    static func decode(_ value: String) throws -> DecodedDataURL {
        guard value.hasPrefix("data:") else {
            throw DataURLDecodingError.invalidPrefix
        }
        guard let commaIndex = value.firstIndex(of: ",") else {
            throw DataURLDecodingError.missingSeparator
        }

        let metadataStart = value.index(value.startIndex, offsetBy: 5)
        let metadata = String(value[metadataStart..<commaIndex])
        let payloadStart = value.index(after: commaIndex)
        let payload = String(value[payloadStart...])
        let metadataParts = metadata.split(
            separator: ";",
            omittingEmptySubsequences: false
        )
        let mimeType = metadataParts.first.map(String.init).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "text/plain"
        let isBase64 = metadataParts.dropFirst().contains("base64")

        let data: Data?
        if isBase64 {
            data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
        } else if let decodedText = payload.removingPercentEncoding {
            data = decodedText.data(using: .utf8)
        } else {
            data = nil
        }

        guard let data else {
            throw DataURLDecodingError.invalidPayload
        }
        return DecodedDataURL(mimeType: mimeType, data: data)
    }

    static func image(from value: String?) -> UIImage? {
        guard
            let value,
            let decoded = try? decode(value),
            decoded.mimeType.hasPrefix("image/")
        else {
            return nil
        }
        return UIImage(data: decoded.data)
    }
}
