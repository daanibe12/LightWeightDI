import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct LightWeightDIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutowiredMacro.self,
        DIObservableMacro.self,
    ]
}
