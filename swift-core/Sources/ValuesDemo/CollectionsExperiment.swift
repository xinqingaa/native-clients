enum CollectionsExperiment {
    static func run() {
        let composed = "é"
        let decomposed = "e\u{301}"
        print(
            "Unicode：字符相等 \(composed == decomposed)，字节数 \(composed.utf8.count)/\(decomposed.utf8.count)"
        )
        let text = "A👨‍👩‍👧‍👦B"
        let middle = text.index(after: text.startIndex)
        print("字符串：\(text.count) 个字符，中间是 \(text[middle])")
        let numbers = [1, 2, 3, 4]
        print("map：\(numbers.map { $0 * 2 })")
        print("filter：\(numbers.filter { $0.isMultiple(of: 2) })")
        print("compactMap：\(["1", "x", "3"].compactMap(Int.init))")
        print("reduce：\(numbers.reduce(0, +))")
        let dictionary = ["b": 2, "a": 1]
        print("字典：\(dictionary.keys.sorted())，缺失 \(dictionary["c"] == nil)")
        print("集合：\(Set([3, 1, 1, 2]).sorted())")
        let slice = numbers[1...2]
        print("切片起始索引：\(slice.startIndex)，转数组后：\(Array(slice).startIndex)")
        var copy = numbers
        copy[0] = 9
        print("数组值：\(numbers) / \(copy)")
        // lazy 推迟计算，不创建异步任务。
        let deferred = numbers.lazy.map { value in
            print("计算元素 \(value)")
            return value * 10
        }
        print("已建立 lazy，尚未消费")
        print("首项：\(deferred.first ?? 0)")
    }
}
