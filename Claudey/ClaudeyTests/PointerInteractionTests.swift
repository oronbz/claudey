import CoreGraphics
import Testing
@testable import Claudey

struct PointerInteractionTests {
    private let grabbed = CGPoint(x: 500, y: 300)

    private func interaction(from point: CGPoint = CGPoint(x: 100, y: 100)) -> PointerInteraction {
        PointerInteraction(startingAt: point, windowOrigin: grabbed)
    }

    @Test func aStationaryPressIsAClick() {
        var pointer = interaction()

        #expect(pointer.ended(at: CGPoint(x: 100, y: 100)) == .click)
    }

    @Test func slightJitterStillCountsAsAClick() {
        var pointer = interaction()

        #expect(pointer.moved(to: CGPoint(x: 101, y: 99)) == nil)
        #expect(pointer.isDragging == false)
        #expect(pointer.ended(at: CGPoint(x: 101, y: 99)) == .click)
    }

    @Test func passingTheThresholdBecomesADrag() {
        var pointer = interaction()

        let origin = pointer.moved(to: CGPoint(x: 140, y: 130))

        #expect(pointer.isDragging)
        #expect(origin == CGPoint(x: 540, y: 330))
        #expect(pointer.ended(at: CGPoint(x: 140, y: 130)) == .drag)
    }

    @Test func heStaysUnderThePointerAcrossManyMoves() {
        var pointer = interaction()

        #expect(pointer.moved(to: CGPoint(x: 110, y: 100)) == CGPoint(x: 510, y: 300))
        #expect(pointer.moved(to: CGPoint(x: 124, y: 97)) == CGPoint(x: 524, y: 297))
        #expect(pointer.moved(to: CGPoint(x: 60, y: 100)) == CGPoint(x: 460, y: 300))
    }

    @Test func draggingBackToTheStartReturnsHimToWhereHeWasGrabbed() {
        var pointer = interaction()
        _ = pointer.moved(to: CGPoint(x: 160, y: 100))

        #expect(pointer.moved(to: CGPoint(x: 100, y: 100)) == grabbed)
        #expect(pointer.ended(at: CGPoint(x: 100, y: 100)) == .drag)
    }

    @Test func aMoveBelowTheThresholdRequestsNoReposition() {
        var pointer = interaction()

        #expect(pointer.moved(to: CGPoint(x: 102, y: 101)) == nil)
    }
}
