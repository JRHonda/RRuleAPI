import Foundation
import UIKit

/// every two weeks on Monday, Wednesday, Friday
let retrievedRRule = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR"

// MARK: - RRule

do {
    // Decode and modify
    var rrule = try RRule.parse(rrule: retrievedRRule)!
    print(rrule.asRRuleString())
    rrule.byDay?.remove(.wednesday)
    rrule.byMinute?.insert(.minute(30))
    rrule.byHour?.insert(.hour(12))
    rrule.wkst = .monday
    print(rrule.asRRuleString())
    rrule.byHour?.isEmpty
    
    // Encode and print JSON
    let rruleJSONData = try JSONEncoder().encode(rrule)
    print(String(data: rruleJSONData, encoding: .utf8)!)
} catch {
    print(error.localizedDescription)
}


// MARK: - RRule_BruteForce

let rruleBruteForce = RRule_BruteForce.parse(rrule: retrievedRRule)
do {
    let rruleBruteForceJSONData = try JSONEncoder().encode(rruleBruteForce)
    print(String(data: rruleBruteForceJSONData, encoding: .utf8)!)
} catch {
    print(error.localizedDescription)
}
