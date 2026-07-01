import Foundation

public struct BucketingResponse: Codable {
    let campaigns: [Campaign]
    let panic: String?
    let accountSettings: [String: JSONValue]?
    let cdnSettings: String?
    let hasConsented: Bool?

    enum CodingKeys: String, CodingKey { case campaigns, panic, accountSettings, cdnSettings, hasConsented }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        campaigns       = (try? c.decode([Campaign].self, forKey: .campaigns)) ?? []
        panic           = try? c.decode(String.self, forKey: .panic)
        accountSettings = try? c.decode([String: JSONValue].self, forKey: .accountSettings)
        cdnSettings     = try? c.decode(String.self, forKey: .cdnSettings)
        hasConsented    = try? c.decode(Bool.self, forKey: .hasConsented)
    }

    init(campaigns: [Campaign],
         panic: String? = nil,
         accountSettings: [String: JSONValue]? = nil,
         cdnSettings: String? = nil,
         hasConsented: Bool? = nil) {
        self.campaigns       = campaigns
        self.panic           = panic
        self.accountSettings = accountSettings
        self.cdnSettings     = cdnSettings
        self.hasConsented    = hasConsented
    }
}

struct Campaign: Codable {
    let id: String
    let name: String?
    let type: String?
    let slug: String?
    var variationGroups: [VariationGroup]
    let traffic: [String: JSONValue]?

    // MARK: Runtime state (not decoded from JSON)
    var isActive: Bool = false
    var isHidden: Bool = false
    var isForced: Bool = false
    var isTargetingRespected: Bool? = nil

    enum CodingKeys: String, CodingKey { case id, name, type, slug, variationGroups, traffic }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = (try? c.decode(String.self, forKey: .id)) ?? ""
        name            = try? c.decode(String.self, forKey: .name)
        type            = try? c.decode(String.self, forKey: .type)
        slug            = try? c.decode(String.self, forKey: .slug)
        variationGroups = (try? c.decode([VariationGroup].self, forKey: .variationGroups)) ?? []
        traffic         = try? c.decode([String: JSONValue].self, forKey: .traffic)
    }

    /// Assigns the variation matching `fetchedId` (or falls back to reference variation).
    mutating func assignFetchedVariation(id fetchedId: String?) {
        for i in variationGroups.indices {
            for j in variationGroups[i].variations.indices {
                let v = variationGroups[i].variations[j]
                variationGroups[i].variations[j].isAssigned = fetchedId != nil
                    ? v.id == fetchedId
                    : (v.reference ?? false)
            }
        }
    }
}

struct VariationGroup: Codable {
    let id: String
    let name: String?
    var variations: [Variation]
    let targeting: Targeting?

    enum CodingKeys: String, CodingKey { case id, name, variations, targeting }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = (try? c.decode(String.self, forKey: .id)) ?? ""
        name       = try? c.decode(String.self, forKey: .name)
        variations = (try? c.decode([Variation].self, forKey: .variations)) ?? []
        targeting  = try? c.decode(Targeting.self, forKey: .targeting)
    }
}

struct Variation: Codable {
    let id: String
    var name: String?
    let reference: Bool?
    let allocation: Int?
    let modifications: Modification?

    // MARK: Runtime state
    var isAssigned: Bool = false
    var isForced: Bool = false
    var isHidden: Bool = false
    var targetingRejected: Bool = false

    enum CodingKeys: String, CodingKey { case id, name, reference, allocation, modifications }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = (try? c.decode(String.self, forKey: .id)) ?? ""
        name          = try? c.decode(String.self, forKey: .name)
        reference     = try? c.decode(Bool.self, forKey: .reference)
        allocation    = try? c.decode(Int.self, forKey: .allocation)
        modifications = try? c.decode(Modification.self, forKey: .modifications)
    }
}

struct Modification: Codable {
    let type: String
    let value: [String: JSONValue]

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type  = (try? c.decode(String.self, forKey: .type)) ?? ""
        value = (try? c.decode([String: JSONValue].self, forKey: .value)) ?? [:]
    }
}

struct Targeting: Codable {
    let targetingGroups: [TargetingGroup]

    enum CodingKeys: String, CodingKey { case targetingGroups }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        targetingGroups = (try? c.decode([TargetingGroup].self, forKey: .targetingGroups)) ?? []
    }
}

struct TargetingGroup: Codable {
    let targetings: [ItemTarget]

    enum CodingKeys: String, CodingKey { case targetings }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        targetings = (try? c.decode([ItemTarget].self, forKey: .targetings)) ?? []
    }
}

struct ItemTarget: Codable {
    let `operator`: String
    let key: String
    let value: JSONValue

    enum CodingKeys: String, CodingKey {
        case `operator`
        case key, value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        `operator` = (try? c.decode(String.self, forKey: .operator)) ?? ""
        key        = (try? c.decode(String.self, forKey: .key)) ?? ""
        value      = (try? c.decode(JSONValue.self, forKey: .value)) ?? .null
    }
}

// MARK: - JSONValue

enum JSONValue: Codable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    var description: String {
        switch self {
        case .string(let v): return v
        case .int(let v):    return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v):   return v ? "true" : "false"
        case .array(let v):  return "[\(v.map(\.description).joined(separator: ", "))]"
        case .object(let v): return "{\(v.map { "\($0.key): \($0.value)" }.joined(separator: ", "))}"
        case .null:          return "null"
        }
    }
}
