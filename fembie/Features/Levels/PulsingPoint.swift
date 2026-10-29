import SwiftUI

struct PulsingPoint: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.blue.opacity(0.7), lineWidth: 2)
                .frame(width: 10, height: 10)
                .phaseAnimator([false, true]) { content, isExpanded in
                    content
                        .scaleEffect(isExpanded ? 2.4 : 1)
                        .opacity(isExpanded ? 0 : 0.8)
                } animation: { isExpanded in
                    isExpanded ? .easeOut(duration: 1.4) : nil
                }

            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
        }
        .drawingGroup()
    }
}
