//
//  RRule.swift
//
//  Created by Justin Honda on 6/23/2022.
//

import Foundation

/**
 RFC 5545
 */
public struct RRule {
    
    /// The raw string values listed below are defined in RFC 5545.
    enum RRuleKey: String, CaseIterable {
        case frequency = "FREQ"
        case interval  = "INTERVAL"
        case byMinute  = "BYMINUTE"
        case byHour    = "BYHOUR"
        case byDay     = "BYDAY"
        case wkst      = "WKST"
    }
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency! // TODO: - Simple conditional mapping based on frequency change i.e. if user has an RRule that defines a WEEKLY frequency but changes to YEARLY, then it would make sense to clear out the data used generate weekly recurrences. There are many scenarios so in order to make this API easy to maintain and use, we'll focus on FREQ level changes only.
    
    /// Default == 1 pursuant to RFC 5545
    /// MUST be a postive integer
    public var interval: Int = 1
    
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
    
    public init(
        frequency: Frequency,
        interval: Int = 1,
        byMinute: Set<Int>,
        byHour: Set<Int>,
        byDay: Set<Day> = [],
        wkst: Day? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.byMinute = byMinute
        self.byHour = byHour
        self.byDay = byDay
        self.wkst = wkst
    }
    
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
                      let key = RRuleKey(rawValue: keyString),
                      let value = kvpComponents.last else {
                    throw RRuleException.invalidInput(.invalidRRule(rRule))
                }
                                
                return (key, value)
            }
        
        func separate<T>(_ value: String, convertTo castType: (String) -> T?) -> [T] {
            value.components(separatedBy: ",").compactMap { castType($0) }
        }
        
        var recurrenceRule = RRule()
        
        rRuleParts.forEach { key, value in
            switch key {
            case .frequency:
                recurrenceRule.frequency = Frequency(rawValue: value)
            case .interval:
                if let interval = Int(value) { recurrenceRule.interval = interval }
            case .byMinute:
                recurrenceRule.byMinute = Set(separate(value, convertTo: Int.init))
            case .byHour:
                recurrenceRule.byHour = Set(separate(value, convertTo: Int.init))
            case .byDay:
                recurrenceRule.byDay = Set(separate(value, convertTo: Day.init))
            case .wkst:
                recurrenceRule.wkst = Day(rawValue: value)
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
    
    /// First, all properties on `RRule` are validated to ensure the generated string is correct.
    /// Lastly, all parts, that are present and "should" be added to the RRule string, are added.
    /// - Returns: A correct (pursuant to RFC 5545) RRule string representation of an `RRule`
    /// instance.
    public func asRRuleString() throws -> String {
        try validate()
        
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
        if rRuleKey == .interval, interval > 1 { return nil }
        return [rRuleKey.rawValue, "=", partValue].joined()
    }
    
    private func stringForPart(_ partValues: [String]?, forKey rRuleKey: RRuleKey) -> String? {
        guard let partValues = partValues, partValues.isEmpty == false else {
            return nil
        }
        let joinedPartValues = partValues.joined(separator: ",")
        
        return [rRuleKey.rawValue, "=", joinedPartValues].joined()
    }
    
    private func validate() throws {
        let failedValidations = RRuleKey.allCases.compactMap { key -> FailedInputValidation? in
            switch key {
            case .frequency:
                if frequency == nil { return .frequency(nil) }
            case .interval:
                if let invalidInterval = RRule.validate(interval, for: .interval) { return .interval(invalidInterval) }
            case .byMinute:
                if let invalidByMinutes = RRule.validate(byMinute, for: .byMinute) { return .byMinute(invalidByMinutes) }
            case .byHour:
                if let invalidByHours = RRule.validate(byMinute, for: .byMinute) { return .byHour(invalidByHours) }
            case .byDay: break
            case .wkst: break
            }
            return nil
        }
        
        if failedValidations.count == 1 { throw RRuleException.invalidInput(failedValidations[0]) }
        if failedValidations.count > 1 { throw RRuleException.multiple(failedValidations) }
    }
    
    private typealias IntValidator = (Int) -> Bool
    
    private enum TypesRequiringValidation {
        enum Set {
            case byMinute
            case byHour
            
            var validator: IntValidator {
                switch self {
                case .byMinute:
                    return { $0 >= 0 && $0 <= 59 }
                case .byHour:
                    return { $0 >= 0 && $0 <= 23 }
                }
            }
        }
        
        enum Int {
            case interval
            
            var validator: IntValidator {
                switch self {
                case .interval: return { $0 > 0 }
                }
            }
        }
    }
    
    private static func validate(_ values: Set<Int>, for setProperty: TypesRequiringValidation.Set) -> [Int]? {
        let possibleInvalidValues = values.filter { setProperty.validator($0) == false }.compactMap { $0 }
        guard possibleInvalidValues.isEmpty else { return possibleInvalidValues }
        return nil
    }
    
    private static func validate(_ value: Int, for integerProperty: TypesRequiringValidation.Int) -> Int? {
        integerProperty.validator(value) ? nil : value
    }
    
}

// MARK: - RRule Part Types (not all inclusive due to using primitive types for some parts)

public extension RRule {
    
    enum Frequency: String, CaseIterable {
        case daily  = "DAILY"
        case weekly = "WEEKLY"
    }
    
    /// BYDAY (strings)  and WKST (string) use same inputs. For example, in this RRule string:
    /// `FREQ=DAILY;BYDAY=MO,WE,FR;WKST=MO`
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
                return "⚠️ Pursuant to RFC 5545, FREQ is required. Your RRule -> \(rRule)"
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

// MARK: - CustomDebugStringConvertible

extension RRule: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        """
        \n\(RRule.self):
        \(debugMessage)
        """
    }
    
    private var debugMessage: String {
        RRuleKey.allCases.map {
            var keyValue = "\($0) ="
            switch $0 {
                case .frequency:
                    keyValue += " \(String(describing: frequency))"
                case .interval:
                    keyValue += " \(interval)"
                case .byMinute:
                    keyValue += " \(byMinute)"
                case .byHour:
                    keyValue += " \(byHour)"
                case .byDay:
                    keyValue += " \(byDay)"
                case .wkst:
                    keyValue += " \(String(describing: wkst))"
            }
            return "\t\(keyValue)"
        }
        .joined(separator: "\n")
    }
    
}
