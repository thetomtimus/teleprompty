import SwiftUI

@MainActor
struct OverlayChromeView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text("Private Presenter")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button(model.isPaused ? "Start" : "Pause") {
                model.send(.togglePlayback)
            }
            Button(model.overlaySession.visibility == .visible ? "Hide" : "Show") {
                model.send(.performShortcut(.toggleVisibility))
            }
            Button(model.isLocked ? "Unlock" : "Lock") {
                model.send(.performShortcut(.toggleLock))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 12)
    }
}
