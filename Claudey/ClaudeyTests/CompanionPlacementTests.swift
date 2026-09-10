import Foundation
import Testing
import CoreGraphics
@testable import Claudey

struct CompanionPlacementTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 128, height: 128)

    @Test func withoutASavedPositionHeStandsInTheLowerRight() {
        let origin = CompanionPlacement.origin(saved: nil, size: size, visibleFrames: [screen])

        #expect(screen.contains(CGRect(origin: origin, size: size)))
        #expect(origin.x > screen.midX)
        #expect(origin.y < screen.midY)
    }

    @Test func aSavedPositionOnScreenIsRestoredExactly() {
        let saved = CGPoint(x: 320, y: 480)

        #expect(CompanionPlacement.origin(saved: saved, size: size, visibleFrames: [screen]) == saved)
    }

    @Test func aPositionFromAVanishedScreenIsPulledBackIntoView() {
        let saved = CGPoint(x: 3200, y: -400)

        let origin = CompanionPlacement.origin(saved: saved, size: size, visibleFrames: [screen])

        #expect(screen.contains(CGRect(origin: origin, size: size)))
    }

    @Test func aPositionOnASecondaryScreenIsKept() {
        let secondary = CGRect(x: 1440, y: 200, width: 1920, height: 1080)
        let saved = CGPoint(x: 2000, y: 300)

        let origin = CompanionPlacement.origin(saved: saved, size: size, visibleFrames: [screen, secondary])

        #expect(origin == saved)
    }

    @Test func aPartlyOffscreenPositionIsNudgedFullyIntoView() {
        let saved = CGPoint(x: 1400, y: 850)

        let origin = CompanionPlacement.origin(saved: saved, size: size, visibleFrames: [screen])

        #expect(screen.contains(CGRect(origin: origin, size: size)))
        #expect(origin.x == screen.maxX - size.width)
        #expect(origin.y == screen.maxY - size.height)
    }
}

struct CompanionPositionStoreTests {
    @Test func rememberedPositionSurvivesAcrossLaunches() {
        let defaults = UserDefaults(suiteName: "com.oronbz.Claudey.tests.\(UUID().uuidString)")!
        defer { defaults.removeObject(forKey: "companionOrigin") }

        let store = CompanionPositionStore(defaults: defaults)
        #expect(store.savedOrigin == nil)

        store.savedOrigin = CGPoint(x: 42, y: 84)

        #expect(CompanionPositionStore(defaults: defaults).savedOrigin == CGPoint(x: 42, y: 84))
    }
}
