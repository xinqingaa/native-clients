import Foundation
import Observation

@MainActor
@Observable
final class LifecycleJournal {
    struct Entry: Identifiable, Equatable {
        let id: Int
        let message: String
    }

    private(set) var entries: [Entry] = []
    @ObservationIgnored private var sequence = 0

    func record(_ message: String) {
        sequence += 1
        entries.append(Entry(id: sequence, message: message))
        if entries.count > 60 { entries.removeFirst(entries.count - 60) }
        print("[AppLab][\(sequence)] \(message)")
    }
}
