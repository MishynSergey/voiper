//
//  TheProduct.swift
//  
//
//  Created by Andrei (Work) on 26/07/2023.
//

import Foundation
import StoreKit

public struct TheProduct: Hashable {
    public let skProduct: SKProduct

    public var localizedPrice: String {
        return priceFormatter(locale: skProduct.priceLocale).string(from: skProduct.price) ?? ""
    }
    
    private func priceFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        return formatter
    }

    public var currency: String {
        return skProduct.priceLocale.currencySymbol ?? skProduct.priceLocale.currencyCode ?? ""
    }
    
    public var term: String {
        if let mode = skProduct.introductoryPrice?.paymentMode,
           mode == .freeTrial,
           let period = skProduct.introductoryPrice?.subscriptionPeriod.localizedPeriod() {
            return "\(period) free, then"
        }
        guard let period = skProduct.subscriptionPeriod else { return "unknown" }
        switch period.unit {
        case .day:
            return period.numberOfUnits == 1 ? .day : "\(period.numberOfUnits) \(String.days)"
        case .week:
            return period.numberOfUnits == 1 ? .week : "\(period.numberOfUnits) \(String.weeks)"
        case .month:
            return period.numberOfUnits == 1 ? .month : "\(period.numberOfUnits) \(String.months)"
        case .year:
            return period.numberOfUnits == 1 ? .year : "\(period.numberOfUnits) \(String.years)"
        @unknown default:
            return "unknown".localized
        }
    }
    
    public var termShort: String {
        guard let period = skProduct.subscriptionPeriod else { return "unknown" }
        switch period.unit {
        case .day:
            return period.numberOfUnits == 1 ? "d" : "\(period.numberOfUnits) d"
        case .week:
            return period.numberOfUnits == 1 ? "wk" : "\(period.numberOfUnits) wk"
        case .month:
            return period.numberOfUnits == 1 ? "mo" : "\(period.numberOfUnits) mo"
        case .year:
            return period.numberOfUnits == 1 ? "y" : "\(period.numberOfUnits) y"
        @unknown default:
            return "unknown".localized
        }
    }

    public init(with skProduct: SKProduct) {
        self.skProduct = skProduct
    }
}

fileprivate extension Double {
    func truncate(places: Int) -> Double {
        return Double(floor(pow(10.0, Double(places)) * self) / pow(10.0, Double(places)))
    }
}

fileprivate extension String {
    static var day: String { "day".localized }
    static var days: String { "days".localized }
    static var week: String { "week".localized }
    static var weeks: String { "weeks".localized }
    static var month: String { "month".localized }
    static var months: String { "months".localized }
    static var year: String { "year".localized }
    static var years: String { "years".localized }
}

// MARK: - Getting a test period
class PeriodFormatter {
    static var componentFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }

    static func format(unit: NSCalendar.Unit, numberOfUnits: Int) -> String? {
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.current
        componentFormatter.allowedUnits = [unit]
        switch unit {
        case .day:
            dateComponents.setValue(numberOfUnits, for: .day)
        case .weekOfMonth:
            dateComponents.setValue(numberOfUnits, for: .weekOfMonth)
        case .month:
            dateComponents.setValue(numberOfUnits, for: .month)
        case .year:
            dateComponents.setValue(numberOfUnits, for: .year)
        default:
            return nil
        }

        return componentFormatter.string(from: dateComponents)
    }
}

extension SKProduct.PeriodUnit {
    func toCalendarUnit() -> NSCalendar.Unit {
        switch self {
        case .day:
            return .day
        case .month:
            return .month
        case .week:
            return .weekOfMonth
        case .year:
            return .year
        @unknown default:
            debugPrint("Unknown period unit")
        }
        return .day
    }
}

public extension SKProductSubscriptionPeriod {
    func localizedPeriod() -> String? {
        return PeriodFormatter.format(unit: unit.toCalendarUnit(), numberOfUnits: numberOfUnits)
    }
}
