import Foundation

public struct RRule_BruteForce: Codable {
    public var frequency: String
    public var interval: String = "1"
    public var byMinute: [String] = []
    public var byHour: [String] = []
    public var byDay: [String] = []
}

// MARK: - Parsing

extension RRule_BruteForce {

    public static func parse(rrule: String) -> Self? {
        let parts = rrule.split(separator: Constants.Delimiter.part)

        guard let freq = parts
            .first(where: { $0.contains("FREQ") })?
            .split(separator: Constants.Delimiter.keyValuePair)
            .last
        else { return nil }

        var rrule = RRule_BruteForce(frequency: String(freq))

        if let interval = parts
            .first(where: { $0.contains("INTERVAL") })?
            .split(separator: Constants.Delimiter.keyValuePair)
            .last {
            rrule.interval = String(interval)
        }

        if let byDay = parts
            .first(where: { $0.contains("BYDAY") })?
            .split(separator: Constants.Delimiter.keyValuePair)
            .last?
            .split(separator: Constants.Delimiter.list)
            .map({ String($0) }) {
                rrule.byDay.append(contentsOf: byDay)
        }

        return rrule
    }

}

// MARK: - Private

extension RRule_BruteForce {
    
    private enum Constants {
        enum Delimiter {
            static let part: Character = ";"
            static let keyValuePair: Character = "="
            static let list: Character = ","
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case frequency = "FREQ"
        case interval  = "INTERVAL"
        case byMinute  = "BYMINUTE"
        case byHour    = "BYHOUR"
        case byDay     = "BYDAY"
    }
    
}
