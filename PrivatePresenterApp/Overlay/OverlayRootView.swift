import SwiftUI

/// Deliberately small proof surface. Product chrome and visual polish are deferred until
/// the physical Milestone 0 gate has passed.
struct OverlayRootView: View {
    static let cornerRadius: CGFloat = 18
    static let interiorIsFullyOpaque = true

    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onResizeChanged: (ClampedPanelInteractionController.ResizeEdge, CGSize) -> Void
    let onResizeEnded: () -> Void

    init(
        onDragChanged: @escaping (CGSize) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {},
        onResizeChanged:
            @escaping (
                ClampedPanelInteractionController.ResizeEdge,
                CGSize
            ) -> Void = { _, _ in },
        onResizeEnded: @escaping () -> Void = {}
    ) {
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onResizeChanged = onResizeChanged
        self.onResizeEnded = onResizeEnded
    }

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.16, blue: 0.26)

            VStack(spacing: 12) {
                Text("Private Presenter overlay proof")
                    .font(.system(size: 24, weight: .semibold))
                Text("The diagnostic controller owns select, show, lock, and hide.")
                    .font(.system(size: 16))
            }
            .foregroundStyle(.white)
            .padding(32)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(alignment: .top) {
            interactionZone(edge: nil).frame(height: 36)
        }
        .overlay(alignment: .top) {
            interactionZone(edge: .top).frame(height: 10)
        }
        .overlay(alignment: .bottom) {
            interactionZone(edge: .bottom).frame(height: 10)
        }
        .overlay(alignment: .leading) {
            interactionZone(edge: .left).frame(width: 10)
        }
        .overlay(alignment: .trailing) {
            interactionZone(edge: .right).frame(width: 10)
        }
        .overlay(alignment: .topLeading) {
            interactionZone(edge: .topLeft).frame(width: 18, height: 18)
        }
        .overlay(alignment: .topTrailing) {
            interactionZone(edge: .topRight).frame(width: 18, height: 18)
        }
        .overlay(alignment: .bottomLeading) {
            interactionZone(edge: .bottomLeft).frame(width: 18, height: 18)
        }
        .overlay(alignment: .bottomTrailing) {
            interactionZone(edge: .bottomRight).frame(width: 18, height: 18)
        }
    }

    private func interactionZone(
        edge: ClampedPanelInteractionController.ResizeEdge?
    ) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if let edge {
                            onResizeChanged(edge, value.translation)
                        } else {
                            onDragChanged(value.translation)
                        }
                    }
                    .onEnded { _ in
                        if edge == nil {
                            onDragEnded()
                        } else {
                            onResizeEnded()
                        }
                    }
            )
    }
}
