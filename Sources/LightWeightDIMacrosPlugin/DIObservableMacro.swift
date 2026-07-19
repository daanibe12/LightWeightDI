import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@DIObservable` with `@Autowired`-aware member attributes.
/// `@Autowired` properties receive `@ObservationIgnored` so they compose with the `@Autowired` accessor macro.
public struct DIObservableMacro {
    static let moduleName = "Observation"
    static let conformanceName = "Observable"
    static var qualifiedConformanceName: String { "\(moduleName).\(conformanceName)" }
    static let registrarTypeName = "ObservationRegistrar"
    static var qualifiedRegistrarTypeName: String { "\(moduleName).\(registrarTypeName)" }
    static let trackedMacroName = "ObservationTracked"
    static let ignoredMacroName = "ObservationIgnored"
    static let autowiredMacroName = "Autowired"
    static let registrarVariableName = "_$observationRegistrar"

    static func registrarVariable(_ observableType: TokenSyntax, context: some MacroExpansionContext) -> DeclSyntax {
        """
        @\(raw: ignoredMacroName) private let \(raw: registrarVariableName) = \(raw: qualifiedRegistrarTypeName)()
        """
    }

    static func accessFunction(_ observableType: TokenSyntax, context: some MacroExpansionContext) -> DeclSyntax {
        let memberGeneric = context.makeUniqueName("Member")
        return """
        internal nonisolated func access<\(memberGeneric)>(
            keyPath: KeyPath<\(observableType), \(memberGeneric)>
        ) {
            \(raw: registrarVariableName).access(self, keyPath: keyPath)
        }
        """
    }

    static func withMutationFunction(_ observableType: TokenSyntax, context: some MacroExpansionContext) -> DeclSyntax {
        let memberGeneric = context.makeUniqueName("Member")
        let mutationGeneric = context.makeUniqueName("MutationResult")
        return """
        internal nonisolated func withMutation<\(memberGeneric), \(mutationGeneric)>(
            keyPath: KeyPath<\(observableType), \(memberGeneric)>,
            _ mutation: () throws -> \(mutationGeneric)
        ) rethrows -> \(mutationGeneric) {
            try \(raw: registrarVariableName).withMutation(of: self, keyPath: keyPath, mutation)
        }
        """
    }

    static func shouldNotifyObserversNonEquatableFunction(
        _ observableType: TokenSyntax,
        context: some MacroExpansionContext
    ) -> DeclSyntax {
        let memberGeneric = context.makeUniqueName("Member")
        return """
        private nonisolated func shouldNotifyObservers<\(memberGeneric)>(_ lhs: \(memberGeneric), _ rhs: \(memberGeneric)) -> Bool { true }
        """
    }

    static func shouldNotifyObserversEquatableFunction(
        _ observableType: TokenSyntax,
        context: some MacroExpansionContext
    ) -> DeclSyntax {
        let memberGeneric = context.makeUniqueName("Member")
        return """
        private nonisolated func shouldNotifyObservers<\(memberGeneric): Equatable>(_ lhs: \(memberGeneric), _ rhs: \(memberGeneric)) -> Bool { lhs != rhs }
        """
    }

    static func shouldNotifyObserversNonEquatableObjectFunction(
        _ observableType: TokenSyntax,
        context: some MacroExpansionContext
    ) -> DeclSyntax {
        let memberGeneric = context.makeUniqueName("Member")
        return """
        private nonisolated func shouldNotifyObservers<\(memberGeneric): AnyObject>(_ lhs: \(memberGeneric), _ rhs: \(memberGeneric)) -> Bool { lhs !== rhs }
        """
    }

    static func shouldNotifyObserversEquatableObjectFunction(
        _ observableType: TokenSyntax,
        context: some MacroExpansionContext
    ) -> DeclSyntax {
        let memberGeneric = context.makeUniqueName("Member")
        return """
        private nonisolated func shouldNotifyObservers<\(memberGeneric): Equatable & AnyObject>(_ lhs: \(memberGeneric), _ rhs: \(memberGeneric)) -> Bool { lhs != rhs }
        """
    }

    static var ignoredAttribute: AttributeSyntax {
        AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier(ignoredMacroName))
        )
    }

    static var trackedAttribute: AttributeSyntax {
        AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier(trackedMacroName))
        )
    }
}

private struct DIObservableDiagnostic: DiagnosticMessage {
    enum ID: String { case invalidApplication = "invalid type" }

    var message: String
    var diagnosticID: MessageID
    var severity: DiagnosticSeverity

    init(message: String, id: ID, severity: DiagnosticSeverity = .error) {
        self.message = message
        self.diagnosticID = MessageID(domain: "LightWeightDI", id: id.rawValue)
        self.severity = severity
    }
}

extension DIObservableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else { return [] }
        let observableType = identified.name.trimmed

        if declaration.isEnum {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: DIObservableDiagnostic(
                        message: "'@DIObservable' cannot be applied to enumeration type '\(observableType.text)'",
                        id: .invalidApplication
                    )
                ),
            ])
        }
        if declaration.isStruct {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: DIObservableDiagnostic(
                        message: "'@DIObservable' cannot be applied to struct type '\(observableType.text)'",
                        id: .invalidApplication
                    )
                ),
            ])
        }
        if declaration.isActor {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: DIObservableDiagnostic(
                        message: "'@DIObservable' cannot be applied to actor type '\(observableType.text)'",
                        id: .invalidApplication
                    )
                ),
            ])
        }

        var declarations = [DeclSyntax]()
        declaration.addIfNeeded(registrarVariable(observableType, context: context), to: &declarations)
        declaration.addIfNeeded(accessFunction(observableType, context: context), to: &declarations)
        declaration.addIfNeeded(withMutationFunction(observableType, context: context), to: &declarations)
        declaration.addIfNeeded(shouldNotifyObserversNonEquatableFunction(observableType, context: context), to: &declarations)
        declaration.addIfNeeded(shouldNotifyObserversEquatableFunction(observableType, context: context), to: &declarations)
        declaration.addIfNeeded(shouldNotifyObserversNonEquatableObjectFunction(observableType, context: context), to: &declarations)
        declaration.addIfNeeded(shouldNotifyObserversEquatableObjectFunction(observableType, context: context), to: &declarations)
        return declarations
    }
}

extension DIObservableMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let property = member.as(VariableDeclSyntax.self),
              property.isValidForObservation,
              property.identifier != nil else {
            return []
        }

        if property.hasMacroApplication(ignoredMacroName)
            || property.hasMacroApplication(trackedMacroName) {
            return []
        }

        if property.hasMacroApplication(autowiredMacroName) {
            return [ignoredAttribute]
        }

        return [trackedAttribute]
    }
}

extension DIObservableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        if protocols.isEmpty { return [] }

        let decl: DeclSyntax = """
        extension \(raw: type.trimmedDescription): nonisolated \(raw: qualifiedConformanceName) {}
        """
        return [decl.cast(ExtensionDeclSyntax.self)]
    }
}
