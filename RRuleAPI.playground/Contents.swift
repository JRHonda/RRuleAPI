import Foundation
import UIKit

let retrievedRRule = "FREQ=DAILY;" // "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;BYMINUTE=30,45;WKST=TH"

var rrule = RRule.parse(rrule: retrievedRRule)!

print(rrule.asRRuleString())

rrule.byHour.insert(23)
rrule.wkst = .monday

print(rrule.asRRuleString())
