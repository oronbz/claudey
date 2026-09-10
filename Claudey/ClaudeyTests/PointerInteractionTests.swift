import Testing
import CoreGraphics
@testable import Claudey

struct PointerInteractionTests {
    @Test func aStationaryPressIsAClick() {
        var interaction = PointerInteraction(startingAt: CGPoint(x: 100, y: 100))

        #expect(interaction.ended(at: CGPoint(x: 100, y: 100)) == .click)
    }

    @Test func slightJitterStillCountsAsAClick() {
        var interaction = PointerInteraction(startingAt: CGPoint(x: 100, y: 100))
        _ = interaction.moved(to: CGPoint(x: 101, y: 99))

        #expect(interaction.isDragging == false)
        #expect(interaction.ended(at: CGPoint(x: 101, y: 99)) == .click)
    }

    @Test func passingTheThresholdBecomesADrag() {
        var interaction = PointerInteraction(startingAt: CGPoint(x: 100, y: 100))
        let translation = interaction.moved(to: CGPoint(x: 140, y: 130))

        #expect(interaction.isDragging)
        #expect(translation == CGSize(width: 40, height: 30))
        #expect(interaction.ended(at: CGPoint(x: 140, y: 130)) == .drag)
    }

    @Test func draggingBackToTheStartDoesNotFireAClick() {
        var interaction = PointerInteraction(startingAt: CGPoint(x: 100, y: 100))
        _ = interaction.moved(to: CGPoint(x: 160, y: 100))
        _ = interaction.moved(to: CGPoint(x: 100, y: 100))

        #expect(interaction.ended(at: CGPoint(x: 100, y: 100)) == .drag)
    }

    @Test func eachMoveReportsOnlyTheIncrementalTranslation() {
        var interaction = PointerInteraction(startingAt: CGPoint(x: 0, y: 0))

        #expect(interaction.moved(to: CGPoint(x: 10, y: 0)) == CGSize(width: 10, height: 0))
        #expect(interaction.moved(to: CGPoint(x: 14, y: -3)) == CGSize(width: 4, height: -3))
    }
}
