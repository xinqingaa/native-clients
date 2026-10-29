import Testing
@testable import SwiftCore

@Test func remainingUsesTheDifferenceBetweenTotalAndCompleted() {
    #expect(Practice.remaining(completed: 3, total: 6) == 3)
}
