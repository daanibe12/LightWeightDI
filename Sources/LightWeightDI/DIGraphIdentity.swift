import Foundation
import ObjectiveC

/// Per-root ID so `.graph` caches do not collide across different owners.
enum DIGraphIdentity {
    private static var key: UInt8 = 0

    static func get(_ object: AnyObject) -> UUID? {
        objc_getAssociatedObject(object, &key) as? UUID
    }

    static func getOrCreate(_ object: AnyObject) -> UUID {
        if let existing = get(object) { return existing }
        let id = UUID()
        set(id, on: object)
        return id
    }

    static func set(_ id: UUID, on object: AnyObject) {
        objc_setAssociatedObject(object, &key, id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
