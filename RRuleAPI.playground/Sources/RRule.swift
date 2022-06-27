import Foundation

/** TODOs */
// TODO: - Determine logic for RRule parts that when updated makes sense to modify other RRule parts ??

/**
 RFC 5545
 */
public struct RRule: Codable {
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency
    
    /// Default == 1 pursuant to RFC 5545
    /// Integer converted value must be a postive integer
    public var interval: String? {
        willSet {
            guard let newValue = newValue, let intValue = Int(newValue) else { return }
            precondition(intValue > 0)
        }
    }
    
    /**
    Time input minute component
    
     Using RRule example:
     
        FREQ=DAILY;BYMINUTE=15,30,45;BYHOUR=1,2
     
     The BYMINUTE and BYHOUR are distributive so the above represents
     a total of 6 different times [1:15, 1:30, 1:45, 2:15, 2:30, 2:45].
     
     So a Set type should be sufficient to prevent duplicates and support distributive
     time creation.
     */
    public var byMinute: Set<Minute>?
    
    /// Time input hour component
    public var byHour: Set<Hour>?
    
    /// Date or Date-Time day component
    public var byDay: Set<Day>?
    
    /**
     The WKST rule part specifies the day on which the workweek starts.
     Valid values are MO, TU, WE, TH, FR, SA, and SU.  This is
     significant when a WEEKLY "RRULE" has an interval greater than 1,
     and a BYDAY rule part is specified. ...{more to read in RFC 5545}... . The
     default value is MO.
     */
    public var wkst: Day? // not required, so optional
    
    /**
     Custom decoder to assign empty "defaults" when decoded from RRule string does not contain a corresponding
     part.
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decode(Frequency.self, forKey: .frequency)
        interval = try container.decodeIfPresent(String.self, forKey: .interval)
        byMinute = try container.decodeIfPresent(Set<Minute>.self, forKey: .byMinute) ?? []
        byHour = try container.decodeIfPresent(Set<Hour>.self, forKey: .byHour) ?? []
        byDay = try container.decodeIfPresent(Set<Day>.self, forKey: .byDay) ?? []
        wkst = try container.decodeIfPresent(Day.self, forKey: .wkst)
    }
    
    /**
     Custom encoding ensures we only convert what we actually have into JSON. In other words,
     the produced JSON here should match, in content, with the RRule for the instance.
     */
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frequency, forKey: .frequency)
        try container.encodeRRulePartOptionally(interval, forKey: .interval)
        try container.encodeRRulePartOptionally(byMinute, forKey: .byMinute)
        try container.encodeRRulePartOptionally(byHour, forKey: .byHour)
        try container.encodeRRulePartOptionally(byDay, forKey: .byDay)
        try container.encodeRRulePartOptionally(wkst?.rawValue, forKey: .wkst)
    }
    
}

// MARK: - KeyedEncodingContainer

private extension KeyedEncodingContainer where Self.Key == RRule.CodingKeys {
    
    mutating func encodeRRulePartOptionally<Part: Collection>(
        _ part: Part?,
        forKey codingKey: Key
    ) throws where Part.Element: RRulePartIdentifiable {
        guard let part = part, part.isEmpty == false else { return }
        try self.encode(part.compactMap { $0.rawValue }, forKey: codingKey)
    }
    
    mutating func encodeRRulePartOptionally(_ part: String?, forKey codingKey: Key) throws {
        guard let part = part, part.isEmpty == false else { return }
        try self.encode(part, forKey: codingKey)
    }
    
}

// MARK: - Parsing

extension RRule {
    
    /// Leverages `Codable` to build an `RRule` object
    /// - Parameter rrule: Passed in RRule string formatted as defined in RFC 5545
    /// - Returns: A modifiable `RRule` object of the passed in RRule string
    public static func parse(rrule: String) throws -> Self? {
        // Convert raw RRULE string into individual RRule parts
        let rRuleParts = rrule
            .components(separatedBy: Constants.Delimiter.part)
            .map { $0.components(separatedBy: Constants.Delimiter.keyValuePair) }
            .compactMap { RRulePart(key: $0.first, value: $0.last) }
        
        if rRuleParts.isEmpty { return nil }
        
        // Take RRule parts created above and make JSON
        guard let rRuleData = rRulePartsToJSON(rRuleParts).data(using: .utf8) else {
            return nil
        }
        
        // Take created JSON and decode into RRule
        return try JSONDecoder().decode(Self.self, from: rRuleData)
    }
    
}

// MARK: - Generate RRule String

extension RRule {
    
    public func asRRuleString() -> String {
        // initialize rrule with REQUIRED frequency part
        var rrule = "\(CodingKeys.frequency.rawValue)\(Constants.Delimiter.keyValuePair)\(frequency.rawValue)"
        
        addIfPresent(interval, toRRule: &rrule, forKey: .interval)
        addIfPresent(byMinute, toRRule: &rrule, forKey: .byMinute)
        addIfPresent(byHour, toRRule: &rrule, forKey: .byHour)
        addIfPresent(byDay, toRRule: &rrule, forKey: .byDay)
        addIfPresent(wkst?.rawValue, toRRule: &rrule, forKey: .wkst)
        
        return rrule
    }
    
    private func addIfPresent<Part: Collection>(
        _ part: Part?,
        toRRule rRule: inout String,
        forKey codingKey: CodingKeys
    ) where Part.Element: RRulePartIdentifiable {
        guard let part = part, part.isEmpty == false else { return }
        
        rRule += "\(Constants.Delimiter.part)\(codingKey.rawValue)\(Constants.Delimiter.keyValuePair)"
        
        for (idx, element) in part.enumerated() {
            if idx == part.count - 1 {
                rRule += element.rawValue
                break
            }
            rRule += "\(element.rawValue)\(Constants.Delimiter.list)"
        }
    }
    
    private func addIfPresent<Part: StringProtocol>(_ part: Part?,
                                                    toRRule rRule: inout String,
                                                    forKey codingKey: CodingKeys) {
        guard let part = part, part.isEmpty == false else { return }
        rRule += "\(Constants.Delimiter.part)\(codingKey.rawValue)\(Constants.Delimiter.keyValuePair)\(part)"
    }
    
}

// MARK: - RRule Part Types

fileprivate protocol RRulePartIdentifiable: Codable, Hashable {
    // TODO: - Rename? BENEFIT to keeping this as `rawValue` prevents us from having to explicitly implement in conforming enums that conform to RawRepresentable
    var rawValue: String { get }
}

public extension RRule {
    
    enum Frequency: String, RRulePartIdentifiable {
        case daily  = "DAILY"
        case weekly = "WEEKLY"
    }
    
    enum Day: String, RRulePartIdentifiable {
        case sunday    = "SU"
        case monday    = "MO"
        case tuesday   = "TU"
        case wednesday = "WE"
        case thursday  = "TH"
        case friday    = "FR"
        case saturday  = "SA"
    }
    
    /// Pursuant to RFC 5545, acceptable minute input MUST be in the interval 0 >= minute <= 59 where minute is an integer
    enum Minute: RRulePartIdentifiable {
        case minute(Int)
        
        var rawValue: String {
            switch self {
            case .minute(let minute):
                precondition(minute >= 0 && minute <= 59)
                return String(minute)
            }
        }
    }
    
    /// Pursuant to RFC 5545, acceptable hour input MUST be in the interval 0 >= hour <= 23 where hour is an integer.
    enum Hour: RRulePartIdentifiable {
        case hour(Int)
        
        var rawValue: String {
            switch self {
            case .hour(let hour):
                precondition(hour >= 0 && hour <= 23)
                return String(hour)
            }
        }
    }

    // TODO: - Add other enums
    
}

// MARK: - Private

extension RRule {
    
    private enum Constants {
        enum Delimiter {
            static let part = ";"
            static let keyValuePair = "="
            static let list = ","
        }
    }
    
    /// The raw string values listed below are defined in RFC 5545.
    enum CodingKeys: String, CodingKey {
        case frequency = "FREQ"
        case interval  = "INTERVAL"
        case byMinute  = "BYMINUTE"
        case byHour    = "BYHOUR"
        case byDay     = "BYDAY"
        case wkst      = "WKST"
    }
    
    // TODO: - Look into how this can be built more elegantly, robustly
    private static func rRulePartsToJSON(_ parts: [RRulePart]) -> String {
        var json = "{"
        for (idx, part) in parts.enumerated() {
            if idx == parts.endIndex - 1 {
                json += part.asJSONKeyValuePair() + "}"
                break
            }
            json += part.asJSONKeyValuePair() + ","
        }
        
        return json
    }
    
}

// MARK: - String conforming to RRulePartIdentifiable

/// Raw value hook for `String` type
extension String: RRulePartIdentifiable {
    public var rawValue: String { self }
}
