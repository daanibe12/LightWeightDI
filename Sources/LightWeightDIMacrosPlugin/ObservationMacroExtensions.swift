import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension VariableDeclSyntax {
    var identifierPattern: IdentifierPatternSyntax? {
        bindings.first?.pattern.as(IdentifierPatternSyntax.self)
    }

    var isInstance: Bool {
        for modifier in modifiers {
            for token in modifier.tokens(viewMode: .all) {
                if token.tokenKind == .keyword(.static) || token.tokenKind == .keyword(.class) {
                    return false
                }
            }
        }
        return true
    }

    var identifier: TokenSyntax? {
        identifierPattern?.identifier
    }

    func accessorsMatching(_ predicate: (TokenKind) -> Bool) -> [AccessorDeclSyntax] {
        let accessors: [AccessorDeclListSyntax.Element] = bindings.compactMap { patternBinding in
            switch patternBinding.accessorBlock?.accessors {
            case .accessors(let accessors):
                return accessors
            default:
                return nil
            }
        }.flatMap { $0 }
        return accessors.compactMap { accessor in
            if predicate(accessor.accessorSpecifier.tokenKind) {
                return accessor
            }
            return nil
        }
    }

    var isComputed: Bool {
        if accessorsMatching({ $0 == .keyword(.get) }).count > 0 {
            return true
        }
        return bindings.contains { binding in
            if case .getter = binding.accessorBlock?.accessors {
                return true
            }
            return false
        }
    }

    var isImmutable: Bool {
        bindingSpecifier.tokenKind == .keyword(.let)
    }

    var isValidForObservation: Bool {
        !isComputed && isInstance && !isImmutable && identifier != nil
    }

    func hasMacroApplication(_ name: String) -> Bool {
        attributes.contains { element in
            guard case let .attribute(attribute) = element else { return false }
            return attribute.attributeName.tokens(viewMode: .all).map(\.tokenKind) == [.identifier(name)]
        }
    }
}

extension DeclGroupSyntax {
    func addIfNeeded(_ decl: DeclSyntax?, to declarations: inout [DeclSyntax]) {
        guard let decl else { return }
        if let fn = decl.as(FunctionDeclSyntax.self) {
            if !hasMemberFunction(equivalentTo: fn) {
                declarations.append(decl)
            }
        } else if let property = decl.as(VariableDeclSyntax.self) {
            if !hasMemberProperty(equivalentTo: property) {
                declarations.append(decl)
            }
        }
    }

    func hasMemberFunction(equivalentTo other: FunctionDeclSyntax) -> Bool {
        memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == other.name.text
        }
    }

    func hasMemberProperty(equivalentTo other: VariableDeclSyntax) -> Bool {
        memberBlock.members.contains { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return false }
            return variable.identifier?.text == other.identifier?.text
        }
    }

    var isClass: Bool { self.is(ClassDeclSyntax.self) }
    var isActor: Bool { self.is(ActorDeclSyntax.self) }
    var isEnum: Bool { self.is(EnumDeclSyntax.self) }
    var isStruct: Bool { self.is(StructDeclSyntax.self) }
}
