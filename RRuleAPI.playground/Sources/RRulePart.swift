import Foundation

/// Used internally within `RRule`
internal struct RRulePart {
    
    private enum RRuleKey: String {
        case freq = "FREQ"
        case interval = "INTERVAL"
        case byDay = "BYDAY"
    }
    
    // MARK: - Properties
    
    let key: String
    var value: Any {
        switch _rruleKey {
            case .freq, .interval:
                return _value
            case .byDay:
                return makeArrayOfValuesForValue()
        }
    }
    
    // MARK: - Failable Initializer
    
    init?(key: String?, value: String?) {
        guard let key = key,
              let rruleKey = RRuleKey(rawValue: key),
              let value = value else { return nil }
        self.key = key
        self._rruleKey = rruleKey
        self._value = value
    }
    
    // MARK: - Public
    
    func asRRuleString() -> String {
        "\(key)=\(_value)"
    }
    
    func asJSONKeyValuePair() -> String {
        switch _rruleKey {
            case .byDay:
                return "\"\(key)\": \(value)" // array
            case .freq, .interval:
                return "\"\(key)\": \"\(value)\"" // string
        }
    }
    
    // MARK: - Private
    
    private let _rruleKey: RRuleKey
    private let _value: String
    
    /// All RRule parts that support multiple values are COMMA-seperated
    private func makeArrayOfValuesForValue() -> Any {
        precondition(_rruleKey == .byDay)
        return _value.split(separator: ",")
    }
    
}
