import Foundation

public struct RRule: Codable {
    /// REQUIRED pursuant to RFC 5545
    public var frequency: String
    /// Default == 1 pursuant to RFC 5545
    public var interval: String?
    public var byMinute: [String]?
    public var byHour: [String]?
    public var byDay: [String]?
    /**
     The WKST rule part specifies the day on which the workweek starts.
     Valid values are MO, TU, WE, TH, FR, SA, and SU.  This is
     significant when a WEEKLY "RRULE" has an interval greater than 1,
     and a BYDAY rule part is specified. ...{more to read in RFC 5545}... . The
     default value is MO.
     */
    public var wkst: String?
}

// MARK: - Parsing

extension RRule {
    
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
    
    // TODO: - Brute force, consider a different approach
    public func asRRuleString() -> String {
        var rrule = "\(CodingKeys.frequency.rawValue)\(Constants.Delimiter.keyValuePair)\(frequency)"
        if let interval = interval {
            rrule += "\(Constants.Delimiter.part)\(CodingKeys.interval.rawValue)\(Constants.Delimiter.keyValuePair)\(interval)"
        }
        
        // See `wkst` block comment above for this logic - however, this may not be needed (TBD).
        if let interval = interval,
           let intervalInt = Int(interval),
           intervalInt > 1,
           frequency == "WEEKLY",
           let byDay = byDay,
           byDay.isEmpty == false {
            rrule += "\(Constants.Delimiter.part)\(CodingKeys.wkst.rawValue)\(Constants.Delimiter.keyValuePair)\(wkst ?? byDay[0])"
        }
        
        if let byDay = byDay {
            
            // TODO: Algo Can be generalized
            rrule += "\(Constants.Delimiter.part)\(CodingKeys.byDay.rawValue)\(Constants.Delimiter.keyValuePair)"
            for (idx, day) in byDay.enumerated() {
                if idx == byDay.endIndex - 1 {
                    rrule += day
                    break
                }
                rrule += "\(day)\(Constants.Delimiter.list)"
            }
        }
        
        if let byHour = byHour {
            // TODO: Algo Can be generalized
            rrule += "\(Constants.Delimiter.part)\(CodingKeys.byHour.rawValue)\(Constants.Delimiter.keyValuePair)"
            for (idx, hour) in byHour.enumerated() {
                if idx == byHour.endIndex - 1 {
                    rrule += hour
                    break
                }
                rrule += "\(hour)\(Constants.Delimiter.list)"
            }
        }
        
        return rrule
    }
    
}

// MARK: - Private

extension RRule {
    
    private enum Constants {
        enum RRulePartDefault {
            static let interval = "1"
            static let wkst = "MO"
        }
        enum Delimiter {
            static let part = ";"
            static let keyValuePair = "="
            static let list = ","
        }
    }
    
    private enum CodingKeys: String, CodingKey {
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
