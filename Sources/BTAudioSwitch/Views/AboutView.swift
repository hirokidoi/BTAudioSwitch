import AppKit
import SwiftUI

struct AboutView: View {
    private let iconSide: CGFloat = 96
    private let width: CGFloat = 360

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSide, height: iconSide)
            Text(BundleInfo.productName)
                .font(.title2.weight(.semibold))
            Text("Version " + BundleInfo.version)
                .foregroundStyle(.secondary)
            Divider()
                .padding(.vertical, 8)
            Text(AppLicense.nameAndCopyright)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(width: width)
    }
}
