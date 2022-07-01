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
        
        init(_ key: String) throws {
            guard let rRuleKey = RRuleKey(rawValue: key) else {
                throw RRuleException.unknownOrUnsupported(rRulePart: key.isEmpty ? "{empty}" : key)
            }
            self = rRuleKey
        }
    }
    
    /// 24-hour time format
    public enum RRuleDefault: Int {
        case morning   = 8
        case afternoon = 12
        case evening   = 17
        case bedtime   = 21
        
        var rRule: RRule {
            .init(frequency: .daily, byHour: .default(for: .byHour, timeOfDay: self))
        }
    }
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency! // TODO: - Simple conditional mapping based on frequency change i.e. if user has an RRule that defines a WEEKLY frequency but changes to YEARLY, then it would make sense to clear out the data used generate weekly recurrences. There are many scenarios so in order to make this API easy to maintain and use, we'll focus on FREQ level changes only.
    
    /// Default == 1 pursuant to RFC 5545
    /// MUST be a postive integer
    public var interval: RRuleInterval = .init()
    
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
    public var byMinute: RRuleSet = .init(for: .byMinute)
    
    /// Time input hour component
    /// Valid input domain: [0, 23]
    public var byHour: RRuleSet = .init(for: .byHour)
    
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
    
    public init(default rRuleDefault: RRuleDefault) { self = rRuleDefault.rRule }
    
    /// Defaults to desired frequency at 0800
    public init(frequency: Frequency,
                interval: RRuleInterval = .init(),
                byMinute: RRuleSet = .default(for: .byMinute),
                byHour: RRuleSet = .default(for: .byHour),
                byDay: Set<Day> = [],
                wkst: Day? = nil) {
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
                    recurrenceRule.interval = try .init(value)
            case .byMinute:
                recurrenceRule.byMinute = try .init(value, for: .byMinute)
            case .byHour:
                recurrenceRule.byHour = try .init(value, for: .byHour)
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
        guard let frequency = frequency else { throw RRuleException.missingFrequency("\(self)") }
        
        return [
            stringForPart(frequency.rawValue, forKey: .frequency),
            stringForPart("\(interval.value)", forKey: .interval),
            stringForPart(byMinute.underlyingSet.map { "\($0)" }, forKey: .byMinute),
            stringForPart(byHour.underlyingSet.map { "\($0)" }, forKey: .byHour),
            stringForPart(byDay.map { $0.rawValue }, forKey: .byDay),
            stringForPart(wkst?.rawValue, forKey: .wkst)
        ]
            .compactMap { $0 }
            .joined(separator: ";")
    }
    
    private func stringForPart(_ partValue: String?, forKey rRuleKey: RRuleKey) -> String? {
        guard let partValue = partValue else { return nil }
        if rRuleKey == .interval, interval.isValidAndAddableToRRule == false {
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
    
    // TODO: - Try to make generic for other primitive types
    struct RRuleSet {
        
        public enum RRulePartSet {
            case byMinute, byHour
            
            var validator: (Int) -> Bool {
                switch self {
                    case .byMinute: return { $0 >= 0 && $0 <= 59 } // interval [0,59]
                    case .byHour: return { $0 >= 0 && $0 <= 23 }   // interval [0,23]
                }
            }
        }
        
        // MARK: - Properties
        
        private(set) public var underlyingSet: Set<Int> = []
        
        // MARK: - Initializers
        
        public init(for partSet: RRulePartSet) {
            self.rRulePartSet = partSet
        }
        
        public init(_ rawPartValues: String, for partSet: RRulePartSet) throws {
            let byValues = rawPartValues.components(separatedBy: ",").compactMap { Int($0) }
            let validatedValues = try Self.validate(byValues, for: partSet)
            self.underlyingSet = .init(validatedValues)
            self.rRulePartSet = partSet
        }
        
        // MARK: - Public
        
        public mutating func insert(_ element: Int) throws {
            underlyingSet.insert(try validate(element, for: rRulePartSet))
        }
        
        public mutating func removeAll() {
            underlyingSet.removeAll()
        }
        
        public mutating func remove(_ element: Int) -> Int? {
            underlyingSet.remove(element)
        }
        
        public static func `default`(for partSet: RRulePartSet, timeOfDay: RRule.RRuleDefault = .morning) -> RRuleSet {
            var rRuleSet = RRuleSet(for: partSet)
            switch partSet {
                case .byMinute:
                    rRuleSet.underlyingSet.insert(Constants.topOfTheHour)
                case .byHour:
                    rRuleSet.underlyingSet.insert(timeOfDay.rawValue)
            }
            return rRuleSet
        }
        
        // MARK: - Private
        
        private enum Constants {
            static let topOfTheHour = 0
        }
        
        private let rRulePartSet: RRulePartSet
        
        private func validate(_ value: Int, for partSet: RRulePartSet) throws -> Int {
            guard partSet.validator(value) else {
                switch rRulePartSet {
                    case .byMinute:
                        throw RRule.RRuleException.invalidInput(.byMinute(value))
                    case .byHour:
                        throw RRule.RRuleException.invalidInput(.byHour(value))
                }
            }
            return value
        }
        
        private static func validate(_ values: [Int], for partSet: RRulePartSet) throws -> [Int] {
            let possibleInvalidByValues = values.filter { partSet.validator($0) == false }
            guard possibleInvalidByValues.isEmpty else {
                var failedInputException: RRule.FailedInputValidation?
                
                if partSet == .byMinute { failedInputException = .byMinute(possibleInvalidByValues) }
                if partSet == .byHour { failedInputException = .byHour(possibleInvalidByValues) }
                
                if let failedInputException = failedInputException {
                    throw RRule.RRuleException.invalidInput(failedInputException)
                } else {
                    throw RRule.RRuleException.unknownOrUnsupported(rRulePart: "\(values)")
                }
            }
            return values
        }
        
    }

    struct RRuleInterval {
        
        /// Since INTERVAL's default equals 1, it's not required to be added to an RRule string. So it should be > 1.
        public var isValidAndAddableToRRule: Bool { validator(value) && value > 1 }
        
        private(set) var value: Int = 1
        
        // MARK: - Initializers

        public init() { }
        
        public init(_ rawInterval: String) throws {
            guard let interval = Int(rawInterval), interval > 0 else {
                throw RRuleException.invalidInput(.interval(rawInterval))
            }
            self.value = interval
        }
        
        // MARK: - Public
        
        public mutating func update(_ interval: Int) throws {
            guard validator(interval) else {
                throw RRuleException.invalidInput(.interval(interval))
            }
            value = interval
        }
        
        // MARK: - Private
        
        /// Valid interval [1,∞)
        private let validator: (Int) -> Bool = { $0 > 0 }

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

// MARK: - CustomStringConvertible

extension RRule: CustomStringConvertible {
    
    public var description: String {
        """
        \n\(RRule.self):
        \(desc)
        """
    }
    
    private var desc: String {
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
