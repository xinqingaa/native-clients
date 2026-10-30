import SwiftCore

final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}

struct Envelope { let box: Box }

final class Owner {
    let name: String
    var action: (() -> String)?
    init(_ name: String) { self.name = name }
    func installStrong() { action = { self.name } }
    func installWeak() { action = { [weak self] in self?.name ?? "已释放" } }
    deinit { print("释放：\(name)") }
}

final class Card {
    unowned let owner: Owner
    init(owner: Owner) { self.owner = owner }
}

func cycleExperiment() {
    weak var observed: Owner?
    do {
        let owner = Owner("strong")
        observed = owner
        owner.installStrong()
    }
    print("外部持有结束后仍存活：\(observed != nil)")
    observed?.action = nil
    print("断环后已释放：\(observed == nil)")
}

func weakReader() -> () -> String {
    let owner = Owner("weak")
    owner.installWeak()
    let reader = owner.action!
    withExtendedLifetime(owner) { print("存活时：\(reader())") }
    return reader
}

@main
struct MemoryDemo {
    static func main() {
        let selection = ExperimentSelection(["sharing", "cycles", "captures"])
        if selection.includes("sharing") {
            let original = Envelope(box: Box(1))
            let copy = original
            copy.box.value = 2
            print("结构体内引用共享：\(original.box.value)")
            let boxes = [Box(3)]
            let aliases = boxes
            aliases[0].value = 4
            print("数组内引用共享：\(boxes[0].value)")
        }
        if selection.includes("cycles") { cycleExperiment() }
        if selection.includes("captures") {
            let reader = weakReader()
            print("返回后弱读取：\(reader())")
            let holder = Owner("unowned")
            let card = Card(owner: holder)
            withExtendedLifetime(holder) { print("寿命约定成立时：\(card.owner.name)") }
        }
    }
}
