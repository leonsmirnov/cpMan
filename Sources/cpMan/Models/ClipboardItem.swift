import Foundation
import SwiftData

enum ClipboardContentType: String, Codable {
    case text
    case image
}

@Model
final class ClipboardItem: Identifiable {
    var id: UUID
    var createdAt: Date

    // Source app
    var sourceApp: String?
    var sourceBundleId: String?

    // Content
    var contentType: ClipboardContentType
    var textValue: String?       // plain text / URL string
    var ocrText: String?         // Vision-extracted text from image (populated async)

    // Image metadata (nil for text items)
    var imageFilePath: String?   // absolute path under Application Support/cpMan/Images/
    var imageWidth: Int?
    var imageHeight: Int?
    var imageSizeBytes: Int?
    var imageHash: String?       // SHA-256 hex string for deduplication

    // User flags
    var isPinned: Bool           // pinned items are exempt from pruning

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceApp: String? = nil,
        sourceBundleId: String? = nil,
        contentType: ClipboardContentType,
        textValue: String? = nil,
        ocrText: String? = nil,
        imageFilePath: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageSizeBytes: Int? = nil,
        imageHash: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.sourceBundleId = sourceBundleId
        self.contentType = contentType
        self.textValue = textValue
        self.ocrText = ocrText
        self.imageFilePath = imageFilePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageSizeBytes = imageSizeBytes
        self.imageHash = imageHash
        self.isPinned = isPinned
    }
}
