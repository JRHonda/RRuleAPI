import Foundation

/** TODOs */
// TODO: - Determine logic for RRule parts that when updated makes sense to modify other RRule parts ??

/**
 RFC 5545
 */
public struct RRule {
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency!
    
    /// Default == 1 pursuant to RFC 5545
    /// MUST be a postive integer
    public var interval: Int? {
        didSet {
            guard let interval = interval else { return }
            if interval == 1 { self.interval = nil }
            if interval < 1 { fatalError(FailedInputValidation.interval(interval).message) }
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
     
     Valid input domain: [0, 59]
     */
    public var byMinute: Set<Int> = [] {
        didSet {
            Self.validateInputs(byMinute.map { $0 }, forKey: .byMinute, validator: Self.validatorMap[.byMinute]!)
        }
    }
    
    /// Time input hour component
    /// Valid input domain: [0, 23]
    public var byHour: Set<Int> = [] {
        didSet {
            Self.validateInputs(byHour.map { $0 }, forKey: .byHour, validator: Self.validatorMap[.byHour]!)
        }
    }
    
    /// Date or Date-Time day component
    public var byDay: Set<Day> = []
    
    /**
     The WKST rule part specifies the day on which the workweek starts.
     Valid values are MO, TU, WE, TH, FR, SA, and SU.  This is
     significant when a WEEKLY "RRULE" has an interval greater than 1,
     and a BYDAY rule part is specified. ...{more to read in RFC 5545}... . The
     default value is MO.
     */
    public var wkst: Day?
    
    public init() { }
    
}

// MARK: - Parsing

extension RRule {
    
    /// Parses an RRule string into a modifiable `RRule` instance
    /// - Parameter rrule: Passed in RRule string (should be in format defined in RFC 5545)
    /// - Returns: A modifiable `RRule` object of the passed in RRule string
    public static func parse(rrule: String) -> Self? {
        var rRule = RRule()
        
        // TODO: - Do we want to trim or fail an otherwise valid RRule such as "FREQ=DAILY;BYDAY=MO,WE,FR " <- has empty string at end
        let trimmedRRule = rrule.trimmingCharacters(in: .whitespaces)
        
        if trimmedRRule.isEmpty { return nil }
        
        let rRuleParts = trimmedRRule
            .components(separatedBy: Constants.Delimiter.part)
            .compactMap { kvp -> (String, String)? in
                let kvpComponents = kvp.components(separatedBy: Constants.Delimiter.keyValuePair)
                
                // makes sure rrule is not of the form -> "FREQ=DAILY;INTERVAL="
                if kvpComponents.count == 1 {
                    if let soloComponent = kvpComponents.first, soloComponent == "" {
                        fatalError("Please check your RRule -> \"\(rrule)\" for correctness. It is likely your RRule string has an invalid character at the end of it.")
                    }
                    fatalError("Invalid RRule part (missing key or value) -> \(kvpComponents)")
                }
                
                guard kvpComponents.count == 2,
                      let key = kvpComponents.first,
                      let value = kvpComponents.last else { return nil }
                return (key, value)
            }
        
        guard rRuleParts.isEmpty == false else {
            fatalError("No valid RRule parts contained in RRule string: \(trimmedRRule.isEmpty ? "{empty}" : trimmedRRule)")
        }
        
        Dictionary<String, String>(uniqueKeysWithValues: rRuleParts)
            .forEach { key, value in
                switch RRuleKey(rawValue: key) {
                case .frequency:
                    guard let frequency = Frequency(rawValue: value) else {
                        fatalError(FailedInputValidation.frequency(value).message)
                    }
                    rRule.frequency = frequency
                case .interval:
                    guard let interval = Int(value), interval > 0 else {
                        fatalError(FailedInputValidation.interval(value).message)
                    }
                    rRule.interval = interval != 1 ? interval : nil
                case .byMinute:
                    let minutes = value.components(separatedBy: Constants.Delimiter.list)
                        .compactMap { Int($0) }
                    validateInputs(minutes, forKey: .byMinute, validator: validatorMap[.byMinute]!)
                    rRule.byMinute = Set(minutes)
                case .byHour:
                    let hours = value.components(separatedBy: Constants.Delimiter.list)
                        .compactMap { Int($0) }
                    validateInputs(hours, forKey: .byHour, validator: validatorMap[.byHour]!)
                    rRule.byHour = Set(hours)
                case .byDay:
                    let days = value.components(separatedBy: Constants.Delimiter.list)
                        .compactMap { day -> Day in
                            guard let day = Day(rawValue: day) else {
                                fatalError(FailedInputValidation.byDay(day).message)
                            }
                            return day
                        }
                    rRule.byDay = Set(days)
                case .wkst:
                    guard let wkst = Day(rawValue: value) else {
                        fatalError(FailedInputValidation.wkst(value).message)
                    }
                    rRule.wkst = wkst
                case .none:
                    fatalError("\(key.isEmpty ? "{empty}" : key) is an invalid RRule part or is not yet supported in this API.")
                }
            }
        
        if rRule.frequency == nil {
            fatalError("Pursuant to RFC 5545, FREQ is required. RRule string attempted to parse -> \(trimmedRRule)")
        }
        
        return rRule
    }
    
    private typealias InputValidator = (Int) -> Bool
    
    private static var validatorMap: [RRuleKey: InputValidator] {[
        .byMinute: { $0 >= 0 && $0 <= 59 },
        .byHour: { $0 >= 0 && $0 <= 23 }
    ]}
    
    private static func validateInputs(_ inputs: [Int], forKey codingKey: RRuleKey, validator: InputValidator) {
        let invalidInputs = inputs.filter { !validator($0) }
        if invalidInputs.isEmpty == false {
            if codingKey == .byMinute {
                fatalError(FailedInputValidation.byMinute(invalidInputs).message)
            }
            if codingKey == .byHour {
                fatalError(FailedInputValidation.byHour(invalidInputs).message)
            }
            fatalError("Invalid input(s) for \(codingKey.rawValue): \(invalidInputs)")
        }
    }
    
}

// MARK: - Generate RRule String

extension RRule {
    
    public func asRRuleString() -> String {
        // initialize rrule string with REQUIRED frequency part
        var rrule = "\(RRuleKey.frequency.rawValue)\(Constants.Delimiter.keyValuePair)\(frequency.rawValue)"
        
        addValueForPartIfPresent(interval, toRRule: &rrule, forKey: .interval)
        addValuesForPartIfPresent(byMinute, toRRule: &rrule, forKey: .byMinute)
        addValuesForPartIfPresent(byHour, toRRule: &rrule, forKey: .byHour)
        addValuesForPartIfPresent(byDay.map { $0.rawValue }, toRRule: &rrule, forKey: .byDay)
        addValueForPartIfPresent(wkst?.rawValue, toRRule: &rrule, forKey: .wkst)

        return rrule
    }
    
    private func addValuesForPartIfPresent<Part: Collection>(
        _ part: Part,
        toRRule rRule: inout String,
        forKey codingKey: RRuleKey
    ) {
        guard part.isEmpty == false else { return }
        
        rRule += "\(Constants.Delimiter.part)\(codingKey.rawValue)\(Constants.Delimiter.keyValuePair)"
        
        for (idx, element) in part.enumerated() {
            if idx == part.count - 1 {
                rRule += "\(element)"
                break
            }
            rRule += "\(element)\(Constants.Delimiter.list)"
        }
    }
    
    private func addValueForPartIfPresent(_ value: Any?, toRRule rRule: inout String, forKey codingKey: RRuleKey) {
        guard let value = value else { return }
        rRule += "\(Constants.Delimiter.part)\(RRuleKey.wkst.rawValue)\(Constants.Delimiter.keyValuePair)\(value)"
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

// MARK: - Private

extension RRule {
    
    private enum Constants {
        enum Delimiter {
            static let part         = ";"
            static let keyValuePair = "="
            static let list         = ","
        }
    }
    
    /// The raw string values listed below are defined in RFC 5545.
    enum RRuleKey: String {
        case frequency = "FREQ"
        case interval  = "INTERVAL"
        case byMinute  = "BYMINUTE"
        case byHour    = "BYHOUR"
        case byDay     = "BYDAY"
        case wkst      = "WKST"
    }
    
    enum FailedInputValidation {
        case frequency(Any)
        case interval(Any)
        case byMinute(Any)
        case byHour(Any)
        case byDay(Any)
        case wkst(Any)
        
        var message: String {
            switch self {
            case .frequency(let invalidInput):
                return "Invalid \(RRuleKey.frequency.rawValue) input: \(invalidInput) - MUST be one of the following: \(Frequency.allCases.map { $0.rawValue })"
            case .interval(let invalidInput):
                return "Invalid \(RRuleKey.interval.rawValue) input: \(invalidInput) - MUST be a positive integer."
            case .byMinute(let invalidInput):
                return "Invalid \(RRuleKey.byMinute.rawValue) input(s): \(invalidInput) - Allowed inputs interval -> [0,59]"
            case .byHour(let invalidInput):
                return "Invalid \(RRuleKey.byHour.rawValue) input(s): \(invalidInput) - Allowed inputs interval -> [0,23]"
            case .byDay(let invalidInput):
                return "Invalid \(RRuleKey.byDay.rawValue) input(s): \(invalidInput) - Allowed inputs: \(Day.allCases.map { $0.rawValue })"
            case .wkst(let invalidInput):
                return "Invalid \(RRuleKey.wkst.rawValue) input: \(invalidInput) - Allowed inputs: \(Day.allCases.map { $0.rawValue })"
            }
        }
    }
    
}

extension String {
    static let empty = ""
}
