import SwiftSyntax
import SwiftSyntaxMacros

public struct AutowiredMacro: PeerMacro, AccessorMacro {

    // MARK: - PeerMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let variable = try variableDeclaration(from: declaration)
        let typeName = try typeName(from: variable)
        let propertyName = try propertyName(from: variable)
        let backingName = backingIdentifier(for: propertyName)
        let isDIObservable = enclosingTypeIsDIObservable(in: context)

        if isDIObservable {
            return ["""
                @ObservationIgnored private var \(backingName): \(raw: typeName)?
                """]
        }

        return ["""
            private var \(backingName): \(raw: typeName)?
            """]
    }

    // MARK: - AccessorMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let variable = try variableDeclaration(from: declaration)
        let typeName = try typeName(from: variable)
        let propertyName = try propertyName(from: variable)
        let backingName = backingIdentifier(for: propertyName)
        let isStruct = enclosingTypeIsStruct(in: context)
        let mutatingKeyword = isStruct ? "mutating " : ""

        let sessionSetup: String
        if isStruct {
            sessionSetup = """
                resolver.startGraphSession()
                defer { resolver.endGraphSession() }
                """
        } else {
            sessionSetup = """
                let graphID = DependencyResolver.graphIdentity(for: self)
                resolver.startGraphSession(id: graphID)
                defer { resolver.endGraphSession() }
                """
        }

        let getterBody = """
            if let cached = \(backingName) { return cached }
            let resolver = DependencyResolver.shared
            \(sessionSetup)
            let resolved = resolver.resolve(\(typeName).self)
            \(backingName) = resolved
            return resolved
            """

        return [AccessorDeclSyntax("""
            \(raw: mutatingKeyword)get {
                \(raw: getterBody)
            }
            """)]
    }
}

// MARK: - Helpers

private enum AutowiredMacroError: Error, CustomStringConvertible {
    case notAVariable
    case missingType
    case missingName

    var description: String {
        switch self {
        case .notAVariable:
            return "@Autowired can only be applied to stored properties."
        case .missingType:
            return "@Autowired requires an explicit type annotation."
        case .missingName:
            return "@Autowired requires a property name."
        }
    }
}

private func variableDeclaration(from declaration: some DeclSyntaxProtocol) throws -> VariableDeclSyntax {
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
        throw AutowiredMacroError.notAVariable
    }
    return variable
}

private func propertyName(from variable: VariableDeclSyntax) throws -> String {
    guard let binding = variable.bindings.first,
          let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
        throw AutowiredMacroError.missingName
    }
    return identifier
}

private func typeName(from variable: VariableDeclSyntax) throws -> String {
    guard let binding = variable.bindings.first,
          let typeAnnotation = binding.typeAnnotation?.type else {
        throw AutowiredMacroError.missingType
    }
    return typeAnnotation.trimmedDescription
}

private func backingIdentifier(for propertyName: String) -> TokenSyntax {
    TokenSyntax.identifier("__di_\(propertyName)")
}

private func immediateEnclosingType(in context: some MacroExpansionContext) -> Syntax? {
    for syntax in context.lexicalContext {
        if syntax.is(StructDeclSyntax.self)
            || syntax.is(ClassDeclSyntax.self)
            || syntax.is(ActorDeclSyntax.self)
            || syntax.is(EnumDeclSyntax.self) {
            return syntax
        }
    }
    return nil
}

private func enclosingTypeIsDIObservable(in context: some MacroExpansionContext) -> Bool {
    guard let type = immediateEnclosingType(in: context) else { return false }

    if let structDecl = type.as(StructDeclSyntax.self) {
        return hasDIObservableAttribute(structDecl.attributes)
    }
    if let classDecl = type.as(ClassDeclSyntax.self) {
        return hasDIObservableAttribute(classDecl.attributes)
    }
    if let actorDecl = type.as(ActorDeclSyntax.self) {
        return hasDIObservableAttribute(actorDecl.attributes)
    }
    return false
}

private func enclosingTypeIsStruct(in context: some MacroExpansionContext) -> Bool {
    immediateEnclosingType(in: context)?.is(StructDeclSyntax.self) ?? false
}

private func hasDIObservableAttribute(_ attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        guard case let .attribute(attribute) = element else { return false }
        let name = attribute.attributeName.trimmedDescription
        return name == "DIObservable" || name.hasSuffix(".DIObservable")
    }
}
