import SwiftUI

extension View {
    /// Uses the platform Liquid Glass treatment on macOS 26+, retaining the
    /// native material hierarchy on earlier supported macOS releases.
    @ViewBuilder
    func workframeGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }
}
