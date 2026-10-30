import Foundation
import Synchronization

// 使用受编译器支持的互斥存储满足Timer的@Sendable闭包要求。
// Mutex需要macOS 15+；不通过unsafe注解绕过共享状态检查。
@available(macOS 15.0, *)
final class Probe: Sendable {
    private let storage = Mutex(0)
    func record() { storage.withLock { $0 += 1 } }
    func read() -> Int { storage.withLock { $0 } }
}

@main
struct RunLoopDemo {
    static func main() {
        guard #available(macOS 15.0, *) else {
            print("本实验的Mutex存储要求macOS 15或更高版本")
            return
        }
        runExperiment()
    }

    @available(macOS 15.0, *)
    private static func runExperiment() {
        let probe = Probe()
        let timer = Timer(timeInterval: 0.01, repeats: false) { _ in
            probe.record()
            print("Timer：回调执行")
        }
        let loop = RunLoop.current
        loop.add(timer, forMode: .default)
        defer { timer.invalidate() }
        print("已注册，尚未驱动RunLoop：\(probe.read())")
        // 只驱动自定义模式，默认模式的timer不会因此被处理。
        _ = loop.run(mode: RunLoop.Mode("LessonMode"), before: Date(timeIntervalSinceNow: 0.02))
        print("运行其他mode后：\(probe.read())")
        loop.run(until: Date(timeIntervalSinceNow: 0.1))
        print("驱动default后：\(probe.read())")
        print("一次性timer已失效：\(!timer.isValid)")
    }
}
