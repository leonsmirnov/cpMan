import SwiftUI

struct ImagesSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Enable OCR — extract text from images (searchable)", isOn: $settings.ocrEnabled)
            } header: {
                Text("Processing")
            } footer: {
                Text("Image metadata (EXIF, GPS, XMP) is always removed when an image is saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
