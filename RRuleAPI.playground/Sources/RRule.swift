//
//  RRuleAPI.swift
//
//  Created by Justin Honda on 6/23/2022.
//

import Foundation

/**
 RFC 5545
 */
public struct RRule {
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency! // TODO: - Simple conditional mapping based on frequency change i.e. if user has an RRule that defines a WEEKLY frequency but changes to YEARLY, then it would make sense to clear out the data used generate weekly recurrences. There are many scenarios so in order to make this API easy to maintain and use, we'll focus on FREQ level changes only.
    
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
    public static func parse(rRule: String) throws -> RRule? {
        if rRule.isEmpty { throw RRuleException.emptyRRule }
                
        let rRuleParts = try rRule
            .components(separatedBy: ";")
            .compactMap { kvp -> (RRuleKey, String) in
                let kvpComponents = kvp.components(separatedBy: "=")
                
                guard kvpComponents.count == 2,
                      let keyString = kvpComponents.first,
                      let value = kvpComponents.last else {
                    throw RRuleException.invalidInput(.invalidRRule(rRule))
                }
                
                let key = try RRuleKey(keyString)
                
                return (key, value)
            }
        
        var recurrenceRule = RRule()
        
        try rRuleParts.forEach { key, value in
            switch key {
            case .frequency:
                recurrenceRule.frequency = try Frequency(value)
            case .interval:
                recurrenceRule.interval = try validate(value, forKey: .interval)
            case .byMinute:
                recurrenceRule.byMinute = try validate(value, forKey: .byMinute)
            case .byHour:
                recurrenceRule.byHour = try validate(value, forKey: .byHour)
            case .byDay:
                recurrenceRule.byDay = try Day.validate(value)
            case .wkst:
                recurrenceRule.wkst = try Day(value, for: .wkst)
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
        try RRule.validateAllParts(forRRule: self)
        
        return [
            stringForPart(frequency.rawValue, forKey: .frequency),
            stringForPart("\(interval)", forKey: .interval),
            stringForPart(byMinute.map { "\($0)" }, forKey: .byMinute),
            stringForPart(byHour.map { "\($0)" }, forKey: .byHour),
            stringForPart(byDay.map { $0.rawValue }, forKey: .byDay),
            stringForPart(wkst?.rawValue, forKey: .wkst)
        ]
            .compactMap { $0 }
            .joined(separator: ";")
    }
    
    private func stringForPart(_ partValue: String?, forKey rRuleKey: RRuleKey) -> String? {
        guard let partValue = partValue else { return nil }
        if rRuleKey == .interval, interval == Constants.RRulePartDefault.interval {
            return nil
        }
        return [rRuleKey.rawValue, "=", partValue].joined()
    }
    
    private func stringForPart(_ partValues: [String]?, forKey rRuleKey: RRuleKey) -> String? {
        guard let partValues = partValues, partValues.isEmpty == false else {
            return nil
        }
        let joinedPartValues = partValues.joined(separator: ",")
        
        return [rRuleKey.rawValue, "=", joinedPartValues].joined()
    }
    
}

// MARK: - RRule Part Types (not all inclusive due to using primitive types for some parts)

public extension RRule {
    
    enum Frequency: String, CaseIterable {
        case daily  = "DAILY"
        case weekly = "WEEKLY"
        
        init(_ freq: String) throws {
            guard let frequency = Frequency(rawValue: freq) else {
                throw RRuleException.invalidInput(.frequency(freq))
            }
            self = frequency
        }
    }
    
    /// BYDAY (strings)  and WKST (string) use same inputs. For example, in this RRule string:
    /// `FREQ=DAILY;BYDAY=MO,WE,FR;WKST=MO`
    enum Day: String, CaseIterable {
    
        enum Part {
            case byDay, wkst
        }
        
        case sunday    = "SU"
        case monday    = "MO"
        case tuesday   = "TU"
        case wednesday = "WE"
        case thursday  = "TH"
        case friday    = "FR"
        case saturday  = "SA"
        
        init(_ day: String, for part: Part) throws {
            guard let day = Day(rawValue: day) else {
                throw RRuleException.invalidInput(part == .byDay ? .byDay(day) : .wkst(day))
            }
            self = day
        }
        
        static func validate(_ value: String) throws -> Set<Day> {
            let byDays = try value.components(separatedBy: ",").map { try Day($0, for: .byDay) }
            return Set(byDays)
        }
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

// MARK: - Validators

private extension RRule {
    
    typealias InputValidator = (Int) -> Bool
    
    static var validators: [RRuleKey: InputValidator] {[
        .interval: { $0 > 0 },              // interval [1,∞)
        .byMinute: { $0 >= 0 && $0 <= 59 }, // interval [0,59]
        .byHour: { $0 >= 0 && $0 <= 23 }    // interval [0,23]
    ]}
    
    // PARSING
    static func validate(_ value: String, forKey rRuleKey: RRuleKey) throws -> Int {
        if rRuleKey == .interval {
            guard let interval = Int(value), validators[.interval]!(interval) else {
                throw RRuleException.invalidInput(.interval(value))
            }
            return interval
        }
        
        throw RRuleException.unknownOrUnsupported(rRulePart: value)
    }
    
    // PARSING
    static func validate(_ value: String, forKey rRuleKey: RRuleKey) throws -> Set<Int> {
        func _validate(_ value: String, forKey rRuleKey: RRuleKey) throws -> Set<Int> {
            let byValues = value.components(separatedBy: ",").compactMap { Int($0) }
            let possibleInvalidByValues = byValues.filter { RRule.validators[rRuleKey]!($0) == false }
            
            guard possibleInvalidByValues.isEmpty else {
                var failedInputException: FailedInputValidation?
                
                if rRuleKey == .byMinute { failedInputException = .byMinute(possibleInvalidByValues) }
                if rRuleKey == .byHour { failedInputException = .byHour(possibleInvalidByValues) }
                
                if let failedInputException = failedInputException {
                    throw RRuleException.invalidInput(failedInputException)
                } else {
                    throw RRuleException.unknownOrUnsupported(rRulePart: value)
                }
            }
            return Set(byValues)
        }
        
        return rRuleKey == .byMinute
            ? try _validate(value, forKey: .byMinute)
            : try _validate(value, forKey: .byHour)
    }
    
    // GENERATING
    static func validateAllParts(forRRule rRule: RRule) throws {
        // ensure all parts (that need validation) are validated (including parts added in the future)
        let failedValidations = RRuleKey.allCases.compactMap { key -> FailedInputValidation? in
            switch key {
            case .frequency:
                if rRule.frequency == nil { return .frequency(nil) }
            case .interval:
                if validators[.interval]!(rRule.interval) == false { return .interval(rRule.interval) }
            case .byMinute:
                if let invalidByMinutes = validateIntegerPartValues(rRule.byMinute.map { $0 }, validator: validators[.byMinute]) {
                    return .byMinute(invalidByMinutes)
                }
            case .byHour:
                if let invalidByHours = validateIntegerPartValues(rRule.byHour.map { $0 }, validator: validators[.byHour]) {
                    return .byHour(invalidByHours)
                }
            case .byDay: break // enum types make it impossible to add bad data
            case .wkst: break // enum type make it impossible to add bad data
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
    
    typealias InvalidIntegerPartValues = [Int]
    
    // GENERATING
    static func validateIntegerPartValues(_ values: [Int], validator: InputValidator?) -> InvalidIntegerPartValues? {
        guard let validator = validator, values.isEmpty == false else { return nil }
        let invalidValues = values.filter { validator($0) == false }
        return invalidValues.isEmpty ? nil : invalidValues
    }
    
}

// MARK: - Private

public extension RRule {
    
    enum Constants {
        enum RRulePartDefault {
            static let interval = 1
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
        
        init(_ key: String) throws {
            guard let rRuleKey = RRuleKey(rawValue: key) else {
                throw RRuleException.unknownOrUnsupported(rRulePart: key.isEmpty ? "{empty}" : key)
            }
            self = rRuleKey
        }
    }
    
}
