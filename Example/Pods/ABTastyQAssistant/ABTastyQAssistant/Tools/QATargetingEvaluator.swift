//
//  QATargetingEvaluator.swift
//  ABTastyQAssistant
//

import FlagShip

enum QATargetingEvaluator {
    static func isConditionMet(_ target: ItemTarget, in userContext: [String: Any]) -> Bool {
        if target.key == "fs_all_users" { return true }
        guard !userContext.isEmpty, let uv = userContext[target.key] else { return false }
        let op = target.operator.uppercased()
        let tv = target.value
        switch op {
        case "EQUALS":
            if case .array(let arr) = tv { return arr.contains { valEquals(uv, $0) } }
            return valEquals(uv, tv)
        case "NOT_EQUALS":
            if case .array(let arr) = tv { return !arr.contains { valEquals(uv, $0) } }
            return !valEquals(uv, tv)
        case "CONTAINS":
            guard let s = uv as? String else { return false }
            if case .string(let t) = tv { return s.contains(t) }
            if case .array(let arr) = tv { return arr.contains { if case .string(let t) = $0 { return s.contains(t) }; return false } }
            return false
        case "NOT_CONTAINS":
            guard let s = uv as? String else { return false }
            if case .string(let t) = tv { return !s.contains(t) }
            if case .array(let arr) = tv { return !arr.contains { if case .string(let t) = $0 { return s.contains(t) }; return false } }
            return false
        case "GREATER_THAN":
            guard let u = toDouble(uv), let t = toDoubleJSON(tv) else { return false }
            return u > t
        case "LOWER_THAN":
            guard let u = toDouble(uv), let t = toDoubleJSON(tv) else { return false }
            return u < t
        case "GREATER_THAN_OR_EQUALS":
            guard let u = toDouble(uv), let t = toDoubleJSON(tv) else { return false }
            return u >= t
        case "LOWER_THAN_OR_EQUALS":
            guard let u = toDouble(uv), let t = toDoubleJSON(tv) else { return false }
            return u <= t
        case "STARTS_WITH":
            guard let s = uv as? String else { return false }
            if case .string(let t) = tv { return s.hasPrefix(t) }
            if case .array(let arr) = tv { return arr.contains { if case .string(let t) = $0 { return s.hasPrefix(t) }; return false } }
            return false
        case "ENDS_WITH":
            guard let s = uv as? String else { return false }
            if case .string(let t) = tv { return s.hasSuffix(t) }
            if case .array(let arr) = tv { return arr.contains { if case .string(let t) = $0 { return s.hasSuffix(t) }; return false } }
            return false
        default:
            return false
        }
    }

    static func valEquals(_ uv: Any, _ tv: JSONValue) -> Bool {
        switch tv {
        case .string(let s): return (uv as? String) == s
        case .int(let i):
            if let u = uv as? Int { return u == i }
            if let n = uv as? NSNumber { return n.intValue == i }
            if let u = uv as? Double { return u == Double(i) }
            return false
        case .double(let d):
            if let u = uv as? Double { return u == d }
            if let n = uv as? NSNumber { return n.doubleValue == d }
            if let u = uv as? Int { return Double(u) == d }
            return false
        case .bool(let b):
            if let u = uv as? Bool { return u == b }
            if let n = uv as? NSNumber { return n.boolValue == b }
            return false
        default:
            return false
        }
    }

    static func toDouble(_ val: Any) -> Double? {
        if let d = val as? Double { return d }
        if let i = val as? Int { return Double(i) }
        if let n = val as? NSNumber { return n.doubleValue }
        return nil
    }

    static func toDoubleJSON(_ val: JSONValue) -> Double? {
        switch val {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }
}
