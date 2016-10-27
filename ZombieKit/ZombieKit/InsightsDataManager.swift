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
        
        // 2
        let chart = OCKBarChart(
            title: "Zombie Training Plan",
            text: "Training Compliance and Zombie Risks",
            tintColor: UIColor.green,
            axisTitles: dateStrings,
            axisSubtitles: nil,
            dataSeries: [completionSeries])
        
        return [chart]
    }

}
