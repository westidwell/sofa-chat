import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import SofaChatCore

/// Shown when a locked Pro item is opened. The Apple TV has no web browser,
/// so the link to PRO.md is also a QR code for your phone.
struct ProLockedView: View {
    let feature: ProFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
            Text(feature.name)
                .font(.title)
                .bold()
            Text(feature.summary)
                .font(.title3)
                .multilineTextAlignment(.center)
            Text(feature.lockedMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ProLinkCode()
            Button("OK") { dismiss() }
        }
        .padding(80)
    }
}

/// The full Pro list, opened from the lock button on the main screen.
struct ProOverviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .top, spacing: 80) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sofa Chat Pro")
                    .font(.system(size: 56, weight: .bold))
                Text("Pro is \(PRO_PRICE) (launch price). It isn't open yet: star or watch the repo to hear when it opens.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Two columns, so every summary has room for its whole sentence.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 48, alignment: .topLeading),
                        GridItem(.flexible(), spacing: 48, alignment: .topLeading),
                    ],
                    alignment: .leading,
                    spacing: 32
                ) {
                    ForEach(ProFeature.allCases) { feature in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(feature.name, systemImage: "lock.fill")
                                .font(.headline)
                            Text(feature.summary)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Button("Close") { dismiss() }
            }
            ProLinkCode()
        }
        .padding(80)
    }
}

/// QR code and text for PRO_URL.
struct ProLinkCode: View {
    var body: some View {
        VStack(spacing: 12) {
            if let image = QRCode.image(for: PRO_URL) {
                Image(image, scale: 1, label: Text("QR code for the Pro feature list"))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 260, height: 260)
                    .padding(14)
                    .background(Color.white)
            }
            Text(PRO_URL)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum QRCode {
    static func image(for text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else {
            return nil
        }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
