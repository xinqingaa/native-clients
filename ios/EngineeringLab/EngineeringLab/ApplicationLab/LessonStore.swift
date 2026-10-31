import Foundation
import Observation

struct LearningItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    var note: String
    var isComplete: Bool

    static let samples = [
        LearningItem(
            id: "entry", title: "从入口到页面", note: "找到 App、Scene 与根 View。", isComplete: false),
        LearningItem(id: "state", title: "状态与导航", note: "观察列表与详情如何共享数据。", isComplete: false),
        LearningItem(id: "lifetime", title: "生命周期与恢复", note: "比较返回页面与重新启动。", isComplete: false),
    ]
}

/// 所有页面共享内存数据；只有明确保存才写文件。
@MainActor
@Observable
final class LessonStore {
    private(set) var items = LearningItem.samples
    private(set) var hasLoaded = false
    private(set) var hasUnsavedChanges = false
    private(set) var storageMessage = "尚未读取保存文件"

    @ObservationIgnored private let fileURL: URL

    init(
        fileURL: URL = URL.applicationSupportDirectory
            .appending(path: "ApplicationLab/learning-items.json")
    ) {
        self.fileURL = fileURL
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            storageMessage = "首次运行：使用内置条目"
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            guard snapshot.version == 1,
                snapshot.items.map(\.id) == LearningItem.samples.map(\.id),
                zip(snapshot.items, LearningItem.samples).allSatisfy({ $0.title == $1.title }),
                snapshot.items.allSatisfy({ $0.note.count <= 2_000 })
            else { throw StorageError.invalidSnapshot }
            items = snapshot.items
            storageMessage = "已从文件恢复条目"
            print("[AppLab][storage] loaded")
        } catch {
            storageMessage = "读取失败，暂用内置条目；原文件未删除：\(error.localizedDescription)"
            print("[AppLab][storage] load failed: \(error)")
        }
    }

    func item(id: String) -> LearningItem? { items.first { $0.id == id } }

    func update(id: String, note: String, isComplete: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }), note.count <= 2_000 else {
            return
        }
        var updated = items[index]
        updated.note = note
        updated.isComplete = isComplete
        guard updated != items[index] else { return }
        items[index] = updated
        hasUnsavedChanges = true
        print("[AppLab][state] updated \(id), memory only")
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(Snapshot(version: 1, items: items))
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            hasUnsavedChanges = false
            storageMessage = "保存成功：重新启动后可读取"
            print("[AppLab][storage] saved")
        } catch {
            storageMessage = "保存失败，内存修改仍保留：\(error.localizedDescription)"
            print("[AppLab][storage] save failed: \(error)")
        }
    }

    @discardableResult
    func reset() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            items = LearningItem.samples
            hasUnsavedChanges = false
            storageMessage = "已清除条目文件，恢复内置数据"
            return true
        } catch {
            storageMessage = "清除失败，当前条目未改变：\(error.localizedDescription)"
            return false
        }
    }

    private struct Snapshot: Codable {
        let version: Int
        let items: [LearningItem]
    }

    private enum StorageError: LocalizedError {
        case invalidSnapshot
        var errorDescription: String? { "文件版本或条目内容不符合当前实验约定。" }
    }
}
