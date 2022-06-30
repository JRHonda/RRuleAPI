import Foundation

/**
 RFC 5545
 */
public struct RRule {
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency! // TODO: - Simple conditional mapping based on frequency change i.e. if user has an RRule that defines a WEEKLY frequency but changes to YEARLY, then it would make sense to clear out the data used generate weekly recurrences. There are so many scenarios so in order to make this API easy to maintain and use, we'll focus on FREQ level changes only.
    
    /// Default == 1 pursuant to RFC 5545
    /// MUST be a postive integer
    public var interval: Int = Constants.RRulePartDefault.interval
    
    /**
    Time input minute component
    
     Using RRule example:
     
        FREQ=DAILY;BYMINUTE=15,30,45;BYHOUR=1,2
     
     The BYMINUTE and BYHOUR are distributive so the above represents
     a total of 6 different times [1:15, 1:30, 1:45, 2:15, 2:30, 2:45].
     
     So a Set type should be sufficient to prevent duplicates and support distributive
     time creation.
     
     Valid input domain: [0, 59]
     */
    public var byMinute: Set<Int> = []
    
    /// Time input hour component
    /// Valid input domain: [0, 23]
    public var byHour: Set<Int> = []
    
    /// Date or Date-Time day component
    public var byDay: Set<Day> = []
    
    /**
     The WKST rule part specifies the day on which the workweek starts.
     Valid values are MO, TU, WE, TH, FR, SA, and SU.  This is
     significant when a WEEKLY "RRULE" has an interval greater than 1,
     and a BYDAY rule part is specified. ...{more to read in RFC 5545}... . The
     default value is MO.
     */
    public var wkst: Day? // TODO: - Still deciding if we want to support this on initial API release
    
    public init() { }
    
}

// MARK: - Parsing

extension RRule {
    
    /// Parses an RRule string into a modifiable `RRule` instance
    /// - Parameter rrule: Passed in RRule string (should be in format defined in RFC 5545)
    /// - Returns: A modifiable `RRule` object of the passed in RRule string
    public static func parse(rRule: String) throws -> Self? {
        if rRule.isEmpty { throw RRuleException.emptyRRule }
                
        let rRuleParts = try rRule
            .components(separatedBy: Constants.Delimiter.part)
            .compactMap { kvp -> (String, String) in
                let kvpComponents = kvp.components(separatedBy: Constants.Delimiter.keyValuePair)
                
                guard kvpComponents.count == 2,
                      let key = kvpComponents.first,
                      let value = kvpComponents.last else {
                    throw RRuleException.invalidInput(.invalidRRule(rRule))
                }
                
                return (key, value)
            }
        
        var recurrenceRule = RRule()
        
        try Dictionary<String, String>(uniqueKeysWithValues: rRuleParts)
            .forEach { key, value in
                switch RRuleKey(rawValue: key) {
                case .frequency:
                    guard let frequency = Frequency(rawValue: value) else {
                        throw RRuleException.invalidInput(.frequency(value))
                    }
                    recurrenceRule.frequency = frequency
                case .interval:
                    guard let interval = Int(value), interval > 0 else {
                        throw RRuleException.invalidInput(.interval(value))
                    }
                    recurrenceRule.interval = interval
                case .byMinute:
                    let byMinutes = value.components(separatedBy: Constants.Delimiter.list)
                        .compactMap { Int($0) }
                    if let invalidByMinutes = validateIntegerPartValues(byMinutes, validator: validators[.byMinute]) {
                        throw RRuleException.invalidInput(.byMinute(invalidByMinutes))
                    }
                    recurrenceRule.byMinute = Set(byMinutes)
                case .byHour:
                    let byHours = value.components(separatedBy: Constants.Delimiter.list)
                        .compactMap { Int($0) }
                    if let invalidByHours = validateIntegerPartValues(byHours, validator: validators[.byHour]) {
                        throw RRuleException.invalidInput(.byHour(invalidByHours))
                    }
                    recurrenceRule.byHour = Set(byHours)
                case .byDay:
                    let days = try value.components(separatedBy: Constants.Delimiter.list)
                        .compactMap { day -> Day in
                            guard let day = Day(rawValue: day) else {
                                throw RRuleException.invalidInput(.byDay(day))
                            }
                            return day
                        }
                    recurrenceRule.byDay = Set(days)
                case .wkst:
                    guard let wkst = Day(rawValue: value) else {
                        throw RRuleException.invalidInput(.wkst(value))
                    }
                    recurrenceRule.wkst = wkst
                case .none:
                    throw RRuleException.unknownOrUnsupported(rRulePart: key.isEmpty ? "{empty}" : key)
                }
            }
        
        if recurrenceRule.frequency == nil {
            throw RRuleException.missingFrequency(rRule)
        }
        
        return recurrenceRule
    }

}

// MARK: - Generate RRule String

extension RRule {
    
    public func asRRuleString() throws -> String {
        try Self.validateAllParts(forRRule: self)
        
        return [
            stringForPart(frequency.rawValue, forKey: .frequency),
            stringForPart("\(interval)", forKey: .interval),
            stringForPart(byMinute.map { "\($0)" }, forKey: .byMinute),
            stringForPart(byHour.map { "\($0)" }, forKey: .byHour),
            stringForPart(byDay.map { $0.rawValue }, forKey: .byDay),
            stringForPart(wkst?.rawValue, forKey: .wkst)
        ]
            .compactMap { $0 }
            .joined(separator: Constants.Delimiter.part)
    }
    
    private func stringForPart(_ part: String?, forKey rRuleKey: RRuleKey) -> String? {
        guard let part = part else { return nil }
        if rRuleKey == .interval, interval == Constants.RRulePartDefault.interval { return nil }
        return "\(rRuleKey.rawValue)\(Constants.Delimiter.keyValuePair)\(part)"
    }
    
    private func stringForPart(_ partValues: [String]?, forKey rRuleKey: RRuleKey) -> String? {
        guard let partValues = partValues, partValues.isEmpty == false else {
            return nil
        }
        return "\(rRuleKey.rawValue)\(Constants.Delimiter.keyValuePair)\(partValues.joined(separator: Constants.Delimiter.list))"
    }
    
}

// MARK: - RRule Part Types (not all inclusive due to using primitive types for some parts)

public extension RRule {
    
    enum Frequency: String, CaseIterable {
        case daily  = "DAILY"
        case weekly = "WEEKLY"
    }
    
    enum Day: String, CaseIterable {
        case sunday    = "SU"
        case monday    = "MO"
        case tuesday   = "TU"
        case wednesday = "WE"
        case thursday  = "TH"
        case friday    = "FR"
        case saturday  = "SA"
    }
    
}

// MARK: - Exception Handling

public extension RRule {
    
    enum RRuleException: Error {
        case missingFrequency(_ message: String)
        case emptyRRule
        case invalidInput(_ failedValidation: FailedInputValidation)
        case unknownOrUnsupported(rRulePart: String)
        case multiple(_ failedValidations: [FailedInputValidation])
        
        public var message: String {
            switch self {
            case .missingFrequency(let rRule):
                return "⚠️ Pursuant to RFC 5545, FREQ is required. RRule string attempted to parse -> \(rRule)"
            case .emptyRRule:
                return "⚠️ Empty RRule string!"
            case .invalidInput(let failedInputValidation):
                return failedInputValidation.message
            case .unknownOrUnsupported(rRulePart: let message):
                return message
            case .multiple(let failedValidations):
                return """
                ⚠️ Multiple Failed Validations ⚠️
                \(failedValidations.enumerated().map { "\($0 + 1). \($1.message)" }.joined(separator: "\n"))
                """
            }
        }
    }
    
    enum FailedInputValidation {
        case invalidRRule(Any)
        case general(Any)
        case frequency(Any?)
        case interval(Any)
        case byMinute(Any)
        case byHour(Any)
        case byDay(Any)
        case wkst(Any)
        
        var message: String {
            switch self {
            case .invalidRRule(let invalidRRule):
                return "⚠️ Please check your RRule -> \"\(invalidRRule)\" for correctness."
            case .frequency(let invalidInput):
                return "⚠️ Invalid \(RRuleKey.frequency.rawValue) input: \(String(describing: invalidInput)) - MUST be one of the following: \(Frequency.allCases.map { $0.rawValue })"
            case .interval(let invalidInput):
                return "⚠️ Invalid \(RRuleKey.interval.rawValue) input: \(invalidInput) - MUST be a positive integer."
            case .byMinute(let invalidInput):
                return "⚠️ Invalid \(RRuleKey.byMinute.rawValue) input(s): \(invalidInput) - Allowed inputs interval -> [0,59]"
            case .byHour(let invalidInput):
                return "⚠️ Invalid \(RRuleKey.byHour.rawValue) input(s): \(invalidInput) - Allowed inputs interval -> [0,23]"
            case .byDay(let invalidInput):
                return "⚠️ Invalid \(RRuleKey.byDay.rawValue) input(s): \(invalidInput) - Allowed inputs: \(Day.allCases.map { $0.rawValue })"
            case .wkst(let invalidInput):
                return "⚠️ Invalid \(RRuleKey.wkst.rawValue) input: \(invalidInput) - Allowed inputs: \(Day.allCases.map { $0.rawValue })"
            case .general(let message):
                return "⚠️ \(message)"
            }
        }
    }
    
}

// MARK: - Private

private extension RRule {
    
    enum Constants {
        enum RRulePartDefault {
            static let interval = 1
        }
        
        enum Delimiter {
            static let part         = ";"
            static let keyValuePair = "="
            static let list         = ","
        }
    }
    
    /// The raw string values listed below are defined in RFC 5545.
    enum RRuleKey: String, CaseIterable {
        case frequency = "FREQ"
        case interval  = "INTERVAL"
        case byMinute  = "BYMINUTE"
        case byHour    = "BYHOUR"
        case byDay     = "BYDAY"
        case wkst      = "WKST"
    }
    
}

// MARK: - Validators

private extension RRule {
    
    typealias InputValidator = (Int) -> Bool
    
    static var validators: [RRuleKey: InputValidator] {[
        .byMinute: { $0 >= 0 && $0 <= 59 }, // interval [0,59]
        .byHour: { $0 >= 0 && $0 <= 23 }    // interval [0,23]
    ]}
    
    typealias InvalidIntegerPartValues = [Int]
    
    static func validateIntegerPartValues(_ values: [Int], validator: InputValidator?) -> InvalidIntegerPartValues? {
        guard let validator = validator, values.isEmpty == false else { return nil }
        let invalidValues = values.filter { !validator($0) }
        return invalidValues.isEmpty ? nil : invalidValues
    }
    
    static func validateAllParts(forRRule rRule: Self) throws {
        // ensure all parts (that need validation) are validated (including parts added in the future)
        let failedValidations = RRuleKey.allCases.compactMap { key -> FailedInputValidation? in
            switch key {
            case .frequency:
                if rRule.frequency == nil { return .frequency(nil) }
            case .interval:
                if rRule.interval < 1 { return .interval(rRule.interval) }
            case .byMinute:
                if let invalidByMinutes = Self.validateIntegerPartValues(rRule.byMinute.map { $0 }, validator: validators[.byMinute]) {
                    return .byMinute(invalidByMinutes)
                }
            case .byHour:
                if let invalidByHours = Self.validateIntegerPartValues(rRule.byHour.map { $0 }, validator: validators[.byHour]) {
                    return .byHour(invalidByHours)
                }
            case .byDay: break
            case .wkst: break
            }
            return nil
        }
        
        if failedValidations.count == 1 {
            throw RRuleException.invalidInput(failedValidations[0])
        }
        
        if failedValidations.count > 1 {
            throw RRuleException.multiple(failedValidations)
        }
    }
    
}

// MARK: - String+Extensions

private extension String {
    static let empty = ""
}
