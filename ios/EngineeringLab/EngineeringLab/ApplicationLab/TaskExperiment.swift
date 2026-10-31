import Foundation
import Observation

/// 面板任务由 SwiftUI 管理；手动任务句柄由这个窗口内的模型持有。
@MainActor
@Observable
final class TaskExperiment {
    private(set) var attachedStatus = "等待显示任务面板"
    private(set) var manualStatus = "尚未开始"
    private(set) var manualIsRunning = false

    @ObservationIgnored private var currentAttachedRun: UUID?
    @ObservationIgnored private var manualTask: Task<Void, Never>?

    func runAttached(input: Int, journal: LifecycleJournal) async {
        let run = UUID()
        currentAttachedRun = run
        attachedStatus = "输入 \(input)：0 / 8"
        journal.record("关联任务开始 input=\(input)")
        defer { journal.record("关联任务结束 input=\(input)") }
        do {
            for step in 1...8 {
                try await Task.sleep(for: .seconds(1))
                try Task.checkCancellation()
                guard currentAttachedRun == run else { return }
                attachedStatus = "输入 \(input)：\(step) / 8"
            }
            attachedStatus = "输入 \(input)：完成"
            journal.record("关联任务完成 input=\(input)")
        } catch is CancellationError {
            if currentAttachedRun == run { attachedStatus = "输入 \(input)：已取消" }
            journal.record("关联任务收到取消 input=\(input)")
        } catch {
            if currentAttachedRun == run { attachedStatus = error.localizedDescription }
            journal.record("关联任务失败 input=\(input)：\(error)")
        }
    }

    func startManual(journal: LifecycleJournal) {
        guard manualTask == nil else { return }
        manualIsRunning = true
        manualStatus = "0 / 8"
        manualTask = Task {
            journal.record("手动任务开始")
            defer {
                self.manualTask = nil
                self.manualIsRunning = false
                journal.record("手动任务结束")
            }
            do {
                for step in 1...8 {
                    try await Task.sleep(for: .seconds(1))
                    try Task.checkCancellation()
                    self.manualStatus = "\(step) / 8"
                }
                self.manualStatus = "完成"
                journal.record("手动任务完成")
            } catch is CancellationError {
                self.manualStatus = "已取消"
                journal.record("手动任务收到取消")
            } catch {
                self.manualStatus = error.localizedDescription
            }
        }
    }

    func cancelManual() {
        manualTask?.cancel()
    }
}
