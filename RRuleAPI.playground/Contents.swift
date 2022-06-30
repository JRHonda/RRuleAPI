//
//  RRuleAPI.swift
//
//  Created by Justin Honda on 6/23/2022.
//

import Foundation
import UIKit

let shouldRunTests = true

if shouldRunTests {
    try RRuleTests.runAll()
}

let retrievedRRule = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;BYMINUTE=30,45;WKST=TH"

do {
    var rrule = try RRule.parse(rRule: retrievedRRule)!
    print(try rrule.asRRuleString())

    rrule.byHour.insert(-1)
    rrule.byMinute.insert(-1)
    rrule.wkst = .monday

    print(try rrule.asRRuleString())
} catch(let error as RRule.RRuleException) {
    print(error.message)
}
