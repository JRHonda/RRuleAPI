import Foundation
import UIKit

/// every two weeks on Monday, Wednesday, Friday
let retrievedRRule = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR"

// MARK: - RRule

do {
    var rrule = try RRule.parse(rrule: retrievedRRule)!
    print(rrule.frequency)
    print(rrule.interval)
    print(rrule.byDay!)
    rrule.byDay?.removeAll(where: { $0 == "WE" })
    rrule.byHour = ["8"]
    print(rrule.asRRuleString())
    
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
