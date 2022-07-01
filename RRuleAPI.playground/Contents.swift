//
//  RRuleAPI.playground
//
//  Created by Justin Honda on 6/23/2022.
//

import Foundation
import UIKit

// MARK: - RRule Tests

print("\nℹ️ MARK: - RRule Tests ℹ️\n")

let shouldRunTests = true

if shouldRunTests {
    try RRuleTests.runAll()
}

// MARK: - Playground Setup

let retrievedRRule = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;BYMINUTE=30,45;WKST=TH"

// MARK: - RRule Intelligent Defaults

print("\nℹ️ MARK: - RRule Intelligent Defaults ℹ️\n")

do {
    let morningRRule = RRule(default: .morning)
    try morningRRule.asRRuleString()
    let afternoonRRule = RRule(default: .afternoon)
    try afternoonRRule.asRRuleString()
    let eveningRRule = RRule(default: .evening)
    try eveningRRule.asRRuleString()
    let bedtimeRRule = RRule(default: .bedtime)
    print("\tBedtime RRule Default (bedtime): \(try bedtimeRRule.asRRuleString())")
} catch let error as RRule.RRuleException {
    print("\t\(error.message)")
}

// MARK: - RRule parse/modify/generate

print("\nℹ️ MARK: - RRule parse/modify/generate ℹ️\n")

do {
    var rrule = try RRule.parse(rRule: retrievedRRule)!
    print("\t\(try rrule.asRRuleString())")
    
    try rrule.byHour.insert(2)
    try rrule.byMinute.insert(2)
    rrule.wkst = .monday

    print("\t\(try rrule.asRRuleString())")
} catch let error as RRule.RRuleException {
    print("\t\(error.message)")
}

// MARK: - RRule Exception Handling

print("\nℹ️ MARK: - RRule Exception Handling ℹ️\n")

do {
    let rrule = RRule()
    _ = try rrule.asRRuleString()
} catch let error as RRule.RRuleException {
    print("\t\(error.message)")
}
