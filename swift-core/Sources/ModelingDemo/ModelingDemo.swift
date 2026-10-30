import SwiftCore

@main
struct ModelingDemo {
    static func main() {
        let selection = ExperimentSelection(["functions", "members", "composition"])
        if selection.includes("functions") { FunctionsExperiment.run() }
        if selection.includes("members") { MembersExperiment.run() }
        if selection.includes("composition") { CompositionExperiment.run() }
    }
}
