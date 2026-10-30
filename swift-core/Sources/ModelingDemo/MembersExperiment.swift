import SwiftCore

struct Point {
    var x: Int
    mutating func move(by distance: Int) { x += distance }
}

final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}

struct Progress {
    var completed: Int {
        didSet { print("didSet：\(oldValue) -> \(completed)") }
    }
    let total: Int
    var remaining: Int { total - completed }
    lazy var initialSummary = "首次访问时已完成 \(completed)"

    init?(completed: Int, total: Int) {
        guard total > 0, (0...total).contains(completed) else { return nil }
        self.completed = completed
        self.total = total
    }
}

class Vehicle {
    let name: String
    init(name: String) { self.name = name }
    convenience init() { self.init(name: "默认车辆") }
    func describe() -> String { name }
}

final class Bicycle: Vehicle {
    override func describe() -> String { "自行车：\(name)" }
}

extension Point {
    var doubled: Int { x * 2 }
    subscript(offset: Int) -> Int { x + offset }
}

enum MembersExperiment {
    static func run() {
        let point = Point(x: 1)
        var pointCopy = point
        pointCopy.move(by: 2)
        let box = Box(1)
        let alias = box
        alias.value = 3
        print("值：\(point.x)/\(pointCopy.x)，引用：\(box.value)，同一对象 \(box === alias)")

        var progress = Progress(completed: 1, total: 6)!
        progress.completed = 2
        print("计算属性：\(progress.remaining)，lazy：\(progress.initialSummary)")
        progress.completed = 3
        print("再次访问：\(progress.remaining)，lazy：\(progress.initialSummary)")
        print("可失败初始化：\(Progress(completed: 7, total: 6) == nil)")

        let vehicle: Vehicle = Bicycle(name: "City")
        print("重写：\(vehicle.describe())，便利初始化：\(Vehicle().name)")
        print("扩展与下标：\(point.doubled) / \(point[5])")
        print("跨模块公开方法：\(Practice.remaining(completed: 2, total: 6))")
    }
}
