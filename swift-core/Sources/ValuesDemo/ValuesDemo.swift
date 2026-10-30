import SwiftCore

@main
struct ValuesDemo {
    static func main() {
        let selection = ExperimentSelection(["optional", "collections", "errors"])
        if selection.includes("optional") { OptionalExperiment.run() }
        if selection.includes("collections") { CollectionsExperiment.run() }
        if selection.includes("errors") { ErrorsExperiment.run() }
    }
}
