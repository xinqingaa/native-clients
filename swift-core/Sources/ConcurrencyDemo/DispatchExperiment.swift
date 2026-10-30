import Dispatch

enum DispatchExperiment {
    static func run() {

        let serial = DispatchQueue(label: "lesson.serial")
        let group = DispatchGroup()
        print("调用方：提交前")
        serial.async(group: group) { print("串行任务 A") }
        serial.async(group: group) { print("串行任务 B") }
        print("调用方：已提交")
        // 仅在同步命令行主入口等待，不是在协作任务或主队列回调内等待自身。
        group.wait()
        print("调用方：两项已结束")
        serial.sync { print("sync：函数返回前执行完") }
        print("调用方：sync 已返回")
        let concurrent = DispatchQueue(label: "lesson.concurrent", attributes: .concurrent)
        let others = DispatchGroup()
        for id in 1...2 {
            concurrent.async(group: others) { print("并发队列任务 \(id)") }
        }
        others.wait()
        print("并发队列：全部结束，任务间输出顺序不固定")
    }
}
