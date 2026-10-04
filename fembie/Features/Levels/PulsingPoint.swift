import Foundation
import SwiftUI

struct PulsingPoint: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.blue.opacity(0.7), lineWidth: 2)
                .frame(width: 10, height: 10)
                .scaleEffect(animate ? 2.4 : 1)
                .opacity(animate ? 0 : 0.8)

            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 1.4)
                    .repeatForever(autoreverses: false)
            ) {
                animate = true
            }
        }
    }
}
