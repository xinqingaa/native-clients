import Foundation

/// 只检查独立模型；iOS 的视图生命周期仍由 Simulator 交互验证。
@main
struct ApplicationLabChecks {
    @MainActor
    static func main() async throws {
        try savedSnapshotWinsAfterRestart()
        try invalidSnapshotsArePreserved()
        try failedSaveKeepsMemoryChanges()
        try await oldCancellationCannotOverwriteNewRun()
        try await manualTaskCanCancelAndRestart()
        print("ApplicationLab checks passed")
    }

    @MainActor
    private static func savedSnapshotWinsAfterRestart() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "nested/items.json")
        let store = LessonStore(fileURL: url)
        store.loadIfNeeded()
        store.update(id: "entry", note: "saved", isComplete: true)
        store.save()
        try check(!store.hasUnsavedChanges, "成功保存必须清除未保存标记")
        store.update(id: "entry", note: "memory-only", isComplete: false)
        store.loadIfNeeded()
        try check(store.item(id: "entry")?.note == "memory-only", "页面重入不能重新读盘覆盖内存")
        let nextProcess = LessonStore(fileURL: url)
        nextProcess.loadIfNeeded()
        try check(nextProcess.item(id: "entry")?.note == "saved", "新模型必须读取保存版本")
        try check(nextProcess.item(id: "entry")?.isComplete == true, "快照应同时保留完成状态")
        try check(store.reset(), "重置应该成功")
        try check(!FileManager.default.fileExists(atPath: url.path), "重置应删除快照")
        let afterReset = LessonStore(fileURL: url)
        afterReset.loadIfNeeded()
        try check(afterReset.items == LearningItem.samples, "重置后新模型必须得到基线")
        print("PASS: saved / memory-only / reset")
    }

    @MainActor
    private static func invalidSnapshotsArePreserved() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "items.json")
        let encodedItems = try JSONEncoder().encode(LearningItem.samples)
        let array = try JSONSerialization.jsonObject(with: encodedItems)
        let unknownVersion = try JSONSerialization.data(withJSONObject: [
            "version": 99, "items": array,
        ])
        let invalidIDs = Data("{\"version\":1,\"items\":[]}".utf8)
        let malformed = Data("not-json".utf8)
        for data in [unknownVersion, invalidIDs, malformed] {
            try data.write(to: url)
            let store = LessonStore(fileURL: url)
            store.loadIfNeeded()
            try check(store.items == LearningItem.samples, "无效输入不能成为正式条目")
            try check(store.storageMessage.contains("读取失败"), "恢复失败必须对调用者可见")
            let retained = try Data(contentsOf: url)
            try check(retained == data, "读取失败不能覆盖或删除原文件")
        }
        print("PASS: invalid snapshot recovery preserves input")
    }

    @MainActor
    private static func failedSaveKeepsMemoryChanges() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let blocker = folder.appending(path: "regular-file")
        try Data("occupied".utf8).write(to: blocker)
        let store = LessonStore(fileURL: blocker.appending(path: "items.json"))
        store.loadIfNeeded()
        store.update(id: "entry", note: "must-retain", isComplete: true)
        store.save()
        try check(store.storageMessage.contains("保存失败"), "路径失败不能显示保存成功")
        try check(store.hasUnsavedChanges, "失败后必须保留未保存标记")
        try check(store.item(id: "entry")?.note == "must-retain", "失败后必须保留用户内存修改")
        print("PASS: failed save keeps changes")
    }

    @MainActor
    private static func oldCancellationCannotOverwriteNewRun() async throws {
        let model = TaskExperiment()
        let journal = LifecycleJournal()
        let old = Task { await model.runAttached(input: 1, journal: journal) }
        try await eventually("第一轮未开始") {
            journal.entries.contains { $0.message == "关联任务开始 input=1" }
        }
        let new = Task { await model.runAttached(input: 2, journal: journal) }
        try await eventually("第二轮未开始") {
            journal.entries.contains { $0.message == "关联任务开始 input=2" }
        }
        old.cancel()
        await old.value
        try check(model.attachedStatus == "输入 2：0 / 8", "旧取消不能把新一轮状态覆盖为已取消")
        new.cancel()
        await new.value
        try check(model.attachedStatus == "输入 2：已取消", "当前轮取消应可见")
        try check(
            journal.entries.filter { $0.message.hasPrefix("关联任务结束") }.count == 2,
            "两轮任务都必须真正结束")
        print("PASS: attached cancellation overlap")
    }

    @MainActor
    private static func manualTaskCanCancelAndRestart() async throws {
        let model = TaskExperiment()
        let journal = LifecycleJournal()
        model.startManual(journal: journal)
        model.startManual(journal: journal)
        try await eventually("手动任务未开始") { journal.entries.contains { $0.message == "手动任务开始" } }
        try check(
            journal.entries.filter { $0.message == "手动任务开始" }.count == 1,
            "运行期间重复点击不能创建第二份任务")
        model.cancelManual()
        try await eventually("取消后手动任务未退出") { !model.manualIsRunning }
        try check(model.manualStatus == "已取消", "取消应记录结果")
        model.startManual(journal: journal)
        try await eventually("结束后没有释放任务句柄") {
            journal.entries.filter { $0.message == "手动任务开始" }.count == 2
        }
        model.cancelManual()
        try await eventually("第二轮手动任务未退出") { !model.manualIsRunning }
        print("PASS: manual cancellation releases handle")
    }

    @MainActor
    private static func eventually(_ failure: String, condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition() {
            try check(ContinuousClock.now < deadline, failure)
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private static func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "AppLabChecks-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(message: message) }
    }

    private struct CheckFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }
}
