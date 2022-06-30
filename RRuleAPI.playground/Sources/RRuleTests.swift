import Foundation
import XCTest

final public class RRuleTests: XCTestCase {
    
    public static func runAll() throws {
        let tests = RRuleTests()
        try tests.testFullValidRRuleString()
        try tests.testInvalidFrequency()
    }
    
    // MARK: - Tests
    
    // TODO: - All `precondition` checks are for playground use only as `XCTAssert`s do not work, remove them once migrated to test target in Medications project
    
    func testFullValidRRuleString() throws {
        let allByMinutes = Array(0...59).map { "\($0)" }.joined(separator: ",")
        let allByHours = Array(0...23).map { "\($0)" }.joined(separator: ",")
        let allDays = RRule.Day.allCases.map { "\($0.rawValue)" }.joined(separator: ",")
        let validRRuleString = "FREQ=DAILY;INTERVAL=2;BYMINUTE=\(allByMinutes);BYHOUR=\(allByHours);BYDAY=\(allDays);WKST=FR"
        let rRule = try XCTUnwrap(try RRule.parse(rRule: validRRuleString))
        let frequency = try XCTUnwrap(rRule.frequency)
        precondition(frequency == .daily, "Failed Test: \(#function) | Asserted frequency == .daily but equals \(frequency)")
        precondition(rRule.interval == 2, "Failed Test: \(#function) | Asserted interval == 2 but equals \(rRule.interval)")
        precondition(rRule.byMinute == Set(0...59), "Failed Test: \(#function) | Error parsing for BYMINUTE")
        precondition(rRule.byHour == Set(0...23), "Failed Test: \(#function) | Error parsing for BYHOUR")
        precondition(rRule.byDay == Set(RRule.Day.allCases), "Failed Test: \(#function) | Error parsing for BYDAY")
        precondition(rRule.wkst == .friday, "Failed Test: \(#function) | Asserted wkst == .friday but equals \(String(describing: rRule.wkst))")
        
        XCTAssertEqual(rRule.frequency, .daily)
        XCTAssertEqual(rRule.interval, 2)
        XCTAssertEqual(rRule.byMinute, Set(0...59))
        XCTAssertEqual(rRule.byHour, Set(0...23))
        XCTAssertEqual(rRule.byDay, Set(RRule.Day.allCases))
        XCTAssertEqual(rRule.wkst, .friday)
    }
    
    func testInvalidFrequency() throws {
        // RRule parsing
        let invalidFrequency = "Daily"
        let invalidRRuleString = "FREQ=\(invalidFrequency)"
        do {
            _ = try RRule.parse(rRule: invalidRRuleString)
        } catch let error as RRule.RRuleException {
            guard case .invalidInput(.frequency(_)) = error else {
                precondition(false, "Failed Test: \(#function) line: \(#line) | \(error.message)")
                XCTFail("Expected Exception -> \(RRule.RRuleException.invalidInput(.frequency(invalidFrequency))) but got \(error)")
                return
            }
        }
        
        // Rrule string generation
        let rRule = RRule()
        do {
            _ = try rRule.asRRuleString()
        } catch let error as RRule.RRuleException {
            guard case .invalidInput(let failedValidation) = error,
                  case .frequency(_) = failedValidation else {
                precondition(false, "Failed Test: \(#function) line: \(#line) | \(error.message)")
                XCTFail("Expected Exception -> \(RRule.RRuleException.invalidInput(.frequency(nil))) but got \(error)")
                return
            }
        }
    }
    
    // TODO: - Add more tests
    
}
