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
            .frame(minWidth: 44, minHeight: 44)
            .presenterAccessibility(
                accessibilityEntry("privatePresenter.overlayPlayback")
            )
            Button(model.overlaySession.visibility == .visible ? "Hide" : "Show") {
                model.send(.performShortcut(.toggleVisibility))
            }
            .frame(minWidth: 44, minHeight: 44)
            .presenterAccessibility(
                accessibilityEntry("privatePresenter.overlayVisibility")
            )
            Button(model.isLocked ? "Unlock" : "Lock") {
                model.send(.performShortcut(.toggleLock))
            }
            .frame(minWidth: 44, minHeight: 44)
            .presenterAccessibility(
                accessibilityEntry("privatePresenter.overlayLock")
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 12)
    }

    private func accessibilityEntry(
        _ identifier: String
    ) -> PresenterAccessibility.Entry {
        PresenterAccessibility.entry(
            identifier,
            state: PresenterAccessibility.state(model: model)
        )
    }
}
