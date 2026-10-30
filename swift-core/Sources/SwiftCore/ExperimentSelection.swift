import Foundation

/// 命令行实验共用的轻量入口；无参数运行整组，也可传一个或多个子例名称。
public struct ExperimentSelection {
    private let selected: Set<String>

    public init(_ available: [String]) {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--list"] || arguments == ["--help"] {
            print("子例：\(available.joined(separator: ", "))")
            print("无参数或 all 运行整组；也可传一个或多个子例名称。")
            selected = []
        } else if arguments.isEmpty || arguments == ["all"] {
            selected = Set(available)
        } else {
            let unknown = arguments.filter { !available.contains($0) }
            guard unknown.isEmpty else {
                let message =
                    "未知子例：\(unknown.joined(separator: ", "))。可用：\(available.joined(separator: ", "))\n"
                FileHandle.standardError.write(Data(message.utf8))
                exit(2)
            }
            selected = Set(arguments)
        }
    }

    public func includes(_ name: String) -> Bool {
        guard selected.contains(name) else { return false }
        print("\n=== \(name) ===")
        return true
    }
}
