import Foundation
import CoreGraphics
import SwiftUI
import Testing
@testable import fembie

@MainActor
struct WellbeingOverlayChartTests {
    @Test func checkInMarkersUseRecordedTimeInsteadOfMidnight() throws {
        let midnight = try Date("2026-10-06T00:00:00Z", strategy: .iso8601)
        let nextMidnight = midnight.addingTimeInterval(86400)
        // Both check-ins belong to the same day but occupy different positions.
        for minutes in [3 * 60 + 7, 21 * 60 + 53] {
            let recordedAt = midnight.addingTimeInterval(Double(minutes) * 60)
            let checkIn = CheckIn(id: UUID(), recordedAt: recordedAt, mood: 5, libido: 8, energy: 2)
            let renderer = ImageRenderer(content:
                WellbeingOverlayChart(checkIns: [checkIn], dateRange: midnight...nextMidnight)
                    .frame(width: 240, height: 100)
                    .background(.white)
                    .environment(\.colorScheme, .light)
            )
            renderer.scale = 1
            let image = try #require(renderer.cgImage)
            let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            let pink = Color.pink.resolve(in: EnvironmentValues())
            var markerXs: [Int] = []
            for y in 45...55 {
                for x in 0..<image.width {
                    let offset = y * context.bytesPerRow + x * 4
                    if abs(Double(pixels[offset]) / 255 - Double(pink.red)) < 0.08,
                       abs(Double(pixels[offset + 1]) / 255 - Double(pink.green)) < 0.08,
                       abs(Double(pixels[offset + 2]) / 255 - Double(pink.blue)) < 0.08 {
                        markerXs.append(x)
                    }
                }
            }
            #expect(markerXs.count > 5)
            let expectedX = Double(minutes) / (24 * 60) * Double(image.width)
            #expect(markerXs.allSatisfy { abs(Double($0) - expectedX) < 4 },
                    "Each marker must use its exact recorded timestamp within the day.")
        }
    }
}
