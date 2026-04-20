import SwiftUI

struct ImagesSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Processing") {
                Toggle("Enable OCR — extract text from images (searchable)", isOn: $settings.ocrEnabled)
                Toggle("Strip image metadata (EXIF) on save", isOn: $settings.stripImageMetadata)
            }

            Section("Downscale on Capture") {
                Toggle("Limit maximum dimension", isOn: $settings.imageMaxDimensionEnabled)
                if settings.imageMaxDimensionEnabled {
                    Stepper(
                        "Max \(settings.imageMaxDimension) px",
                        value: $settings.imageMaxDimension,
                        in: 256...8_192,
                        step: 256
                    )
                }

                Toggle("Limit file size per image", isOn: $settings.imageSizeLimitEnabled)
                if settings.imageSizeLimitEnabled {
                    Stepper(
                        "Max \(settings.imageSizeLimitMB) MB per image",
                        value: $settings.imageSizeLimitMB,
                        in: 1...50
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
