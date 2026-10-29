public enum LessonSummary {
    public static func make(completed: Int, total: Int) -> String {
        precondition(total > 0 && completed >= 0 && completed <= total)
        let remaining = total - completed
        return "已完成 \(completed) / \(total)，剩余 \(remaining)"
    }
}
