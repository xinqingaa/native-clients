import SwiftCore

protocol Named {
    var name: String { get }
    func requiredLabel() -> String
}

extension Named {
    func requiredLabel() -> String { "协议默认" }
    func extraLabel() -> String { "扩展方法" }
}

struct Person: Named {
    let name: String
    func requiredLabel() -> String { "Person 要求实现" }
    func extraLabel() -> String { "Person 同名方法" }
}

struct Robot: Named { let name: String }

// 父类已经用协议默认实现建立遵循，子类新增同名方法并未重写一个父类方法。
class BaseNamed: Named { let name = "Base" }
final class ChildNamed: BaseNamed {
    func requiredLabel() -> String { "子类同名方法" }
}

func same<T: Equatable>(_ left: T, _ right: T) -> Bool { left == right }
func makePerson() -> some Named { Person(name: "Qin") }

protocol Source {
    associatedtype Item
    func read() -> Item
}

struct Constant<T>: Source {
    let value: T
    func read() -> T { value }
}

func readPair<S: Source>(_ source: S) -> (S.Item, S.Item) {
    (source.read(), source.read())
}

extension Constant: Equatable where T: Equatable {}

struct AnyIntSource: Source {
    private let getter: () -> Int
    init<S: Source>(_ source: S) where S.Item == Int { getter = source.read }
    func read() -> Int { getter() }
}

@main
struct ProtocolsDemo {
    static func main() {
        let selection = ExperimentSelection(["dispatch", "abstraction", "associated"])
        let person = Person(name: "Lin")
        if selection.includes("dispatch") {
            let existential: any Named = person
            print("具体类型：\(person.requiredLabel()) / \(person.extraLabel())")
            print("协议视角：\(existential.requiredLabel()) / \(existential.extraLabel())")
            let child = ChildNamed()
            let inherited: any Named = child
            print("继承遵循：\(child.requiredLabel()) / \(inherited.requiredLabel())")
        }
        if selection.includes("abstraction") {
            print("泛型：\(same(2, 2))，some：\(makePerson().name)")
            let mixed: [any Named] = [person, Robot(name: "R1")]
            print("any 异构存储：\(mixed.map(\.name))")
        }
        if selection.includes("associated") {
            let source = Constant(value: 7)
            let pair = readPair(source)
            print("关联类型：\(pair.0)/\(pair.1)，条件遵循：\(source == Constant(value: 7))")
            print("类型擦除：\(AnyIntSource(source).read())")
        }
    }
}
