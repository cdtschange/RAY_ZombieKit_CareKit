//
//  InsightsDataManager.swift
//  ZombieKit
//
//  Created by Mao on 27/10/2016.
//  Copyright © 2016 Razeware. All rights reserved.
//

import Foundation
import CareKit

class InsightsDataManager {
    let store = CarePlanStoreManager.sharedCarePlanStoreManager.store
    var completionData = [(dateComponent: DateComponents, value: Double)]()
    let gatherDataGroup = DispatchGroup()
    
    var pulseData = [DateComponents: Double]()
    var temperatureData = [DateComponents: Double]()
    
    var completionSeries: OCKBarSeries {
        // 1
        let completionValues = completionData.map({ NSNumber(value:$0.value) })
        
        // 2
        let completionValueLabels = completionValues
            .map({ NumberFormatter.localizedString(from: $0, number: .percent)})
        
        // 3
        return OCKBarSeries(
            title: "Zombie Training",
            values: completionValues,
            valueLabels: completionValueLabels,
            tintColor: UIColor.darkOrange())
    }
    
    func fetchDailyCompletion(startDate: DateComponents, endDate: DateComponents) {
        // 1
        gatherDataGroup.enter()
        // 2
        store.dailyCompletionStatus(
            with: .intervention,
            startDate: startDate,
            endDate: endDate,
            // 3
            handler: { (dateComponents, completed, total) in
                let percentComplete = Double(completed) / Double(total)
                self.completionData.append((dateComponents, percentComplete))
            },
            // 4
            completion: { (success, error) in
                guard success else { fatalError(error!.localizedDescription) }
                self.gatherDataGroup.leave()
        })
    }
    
    func updateInsights(_ completion: ((Bool, [OCKInsightItem]?) -> Void)?) {
        guard let completion = completion else { return }
        
        // 1
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            // 2
            let startDateComponents = DateComponents.firstDateOfCurrentWeek
            let endDateComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date())
            
            //TODO: fetch assessment data
            
            self.fetchDailyCompletion(startDate: startDateComponents, endDate: endDateComponents)
            
            
            guard let pulseActivity = self.findActivityWith(ActivityIdentifier.pulse) else { return }
            self.fetchActivityResultsFor(pulseActivity, startDate: startDateComponents,
                                         endDate: endDateComponents) { (fetchedData) in
                                            self.pulseData = fetchedData
            }
            
            guard let temperatureActivity = self.findActivityWith(ActivityIdentifier.temperature) else { return }
            self.fetchActivityResultsFor(temperatureActivity, startDate: startDateComponents,
                                         endDate: endDateComponents) { (fetchedData) in
                                            self.temperatureData = fetchedData
            }
            
            // 3
            self.gatherDataGroup.notify(queue: DispatchQueue.main, execute: {
//                print("completion data: \(self.completionData)")
//                completion(false, nil)
                let insightItems = self.produceInsightsForAdherence()
                completion(true, insightItems)
            })
        }
    }

    func produceInsightsForAdherence() -> [OCKInsightItem] {
        // 1
        let dateStrings = completionData.map({(entry) -> String in
            guard let date = Calendar.current.date(from: entry.dateComponent)
                else { return "" }
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        })
        
        //TODO: Build assessment series
        let pulseAssessmentSeries = barSeriesFor(data: pulseData, title: "Pulse",
                                                 tintColor: UIColor.darkGreen())
        let temperatureAssessmentSeries = barSeriesFor(data: temperatureData, title: "Temperature",
                                                       tintColor: UIColor.darkYellow())
        
        // 2
        let chart = OCKBarChart(
            title: "Zombie Training Plan",
            text: "Training Compliance and Zombie Risks",
            tintColor: UIColor.green,
            axisTitles: dateStrings,
            axisSubtitles: nil,
            dataSeries: [completionSeries, temperatureAssessmentSeries, pulseAssessmentSeries])
        
        return [chart]
    }

    func findActivityWith(_ activityIdentifier: ActivityIdentifier) -> OCKCarePlanActivity? {
        let semaphore = DispatchSemaphore(value: 0)
        var activity: OCKCarePlanActivity?
        
        DispatchQueue.main.async {
            self.store.activity(forIdentifier: activityIdentifier.rawValue) { success, foundActivity, error in
                activity = foundActivity
                semaphore.signal()
            }
        }
        
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return activity
    }
    
    func fetchActivityResultsFor(_ activity: OCKCarePlanActivity,
                                 startDate: DateComponents, endDate: DateComponents,
                                 completionClosure: @escaping (_ fetchedData: [DateComponents: Double]) ->()) {
        var fetchedData = [DateComponents: Double]()
        // 1
        self.gatherDataGroup.enter()
        // 2
        store.enumerateEvents(
            of: activity,
            startDate: startDate,
            endDate: endDate,
            // 3
            handler: { (event, stop) in
                if let event = event,
                    let result = event.result,
                    let value = Double(result.valueString) {
                    fetchedData[event.date] = value
                }
            },
            // 4
            completion: { (success, error) in
                guard success else { fatalError(error!.localizedDescription) }
                completionClosure(fetchedData)
                self.gatherDataGroup.leave()
        })
    }
    
    func barSeriesFor(data: [DateComponents: Double], title: String, tintColor: UIColor) -> OCKBarSeries {
        // 1
        let rawValues = completionData.map({ (entry) -> Double? in
            return data[entry.dateComponent]
        })
        
        // 2
        let values = DataHelpers().normalize(rawValues)
        
        // 3
        let valueLabels = rawValues.map({ (value) -> String in
            guard let value = value else { return "N/A" }
            return NumberFormatter.localizedString(from: NSNumber(value:value), number: .decimal)
        })
        
        // 4
        return OCKBarSeries(
            title: title,
            values: values as [NSNumber],
            valueLabels: valueLabels,
            tintColor: tintColor)
    }
}
