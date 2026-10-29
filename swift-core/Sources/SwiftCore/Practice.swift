public enum Practice {
    public static func remaining(completed: Int, total: Int) -> Int {
        precondition(total > 0 && completed >= 0 && completed <= total)
        return total - completed
    }
}
