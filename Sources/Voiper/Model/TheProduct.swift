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
    public let type: ProductType
        
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
        self.type = ProductType(from: skProduct.productIdentifier)
    }
}

extension TheProduct {
    public enum ProductType: Int, CaseIterable {
        case oneNumberSixMonthsTrial

        case oneNumberWeekly
        case oneNumberMonthly
        
        case secondNumberWeekly
        case secondNumberMonthly
        case secondNumberThreeMonths
        
        case coinPack100
        case coinPack500
        case coinPack1000
        case coinPack2000
        
        case unknown
        
        private static var bundleId: String {
            if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path), let bundle = dict["CFBundleIdentifier"] as? String {
                return bundle
            } else {
                return ""
            }
        }
        
        init(from id: String) {
            switch id {
            case "\(ProductType.bundleId).weekly_1":
                self = .oneNumberWeekly
            case "\(ProductType.bundleId).monthly_1":
                self = .oneNumberMonthly
            case "\(ProductType.bundleId).6months_trial_1":
                self = .oneNumberSixMonthsTrial
    
            case "\(ProductType.bundleId).weekly_2":
                self = .secondNumberWeekly
            case "\(ProductType.bundleId).monthly_2":
                self = .secondNumberMonthly
            case "\(ProductType.bundleId).3months_2":
                self = .secondNumberThreeMonths
    
            case "\(ProductType.bundleId).credit_100":
                self = .coinPack100
            case "\(ProductType.bundleId).credit_500":
                self = .coinPack500
            case "\(ProductType.bundleId).credit_1000":
                self = .coinPack1000
            case "\(ProductType.bundleId).credit_2000":
                self = .coinPack2000
            default:
                self = .unknown
            }
        }
        
        public var id: String? {
            
            switch self {
            case .oneNumberWeekly:
                return "\(ProductType.bundleId).weekly_1"
            case .oneNumberMonthly:
                return "\(ProductType.bundleId).monthly_1"
            case .oneNumberSixMonthsTrial:
                return "\(ProductType.bundleId).6months_trial_1"

    
            case .secondNumberWeekly:
                return "\(ProductType.bundleId).weekly_2"
            case .secondNumberMonthly:
                return "\(ProductType.bundleId).monthly_2"
            case .secondNumberThreeMonths:
                return "\(ProductType.bundleId).3months_2"
      
            case .coinPack100:
                return "\(ProductType.bundleId).credit_100"
            case .coinPack500:
                return "\(ProductType.bundleId).credit_500"
            case .coinPack1000:
                return "\(ProductType.bundleId).credit_1000"
            case .coinPack2000:
                return "\(ProductType.bundleId).credit_2000"

            default:
                return nil
            }
        }
        
        var isSubscription: Bool {
            switch self {
            case .coinPack100, .coinPack500, .coinPack1000, .coinPack2000:
                return false
            default:
                return true
            }
        }
        
        public var isTrial: Bool {
            switch self {
            case .oneNumberSixMonthsTrial:
                return true
            default:
                return false
            }
        }
        
        public var isFirstNumber: Bool {
            switch self {
            case .oneNumberWeekly,
                 .oneNumberMonthly,
                 .oneNumberSixMonthsTrial:

                return true
            default:
                return false
            }
        }
        
        public var isSecondNumber: Bool {
            switch self {
            case .secondNumberWeekly,
                 .secondNumberMonthly,
                 .secondNumberThreeMonths:

                return true
            default:
                return false
            }
        }
        
        public var group: Int {
            switch self {
            case .oneNumberWeekly,
                 .oneNumberMonthly,
                 .oneNumberSixMonthsTrial:
                
                return 1

            case .secondNumberWeekly,
                 .secondNumberMonthly,
                 .secondNumberThreeMonths:

                return 2

            case .coinPack100,
                 .coinPack500,
                 .coinPack1000,
                 .coinPack2000:

                return 3

            case .unknown:
                return -1
            }
        }
        
        public static var coinsPacks: Set<Self> { [.coinPack100, .coinPack500, .coinPack1000, .coinPack2000] }
    }
}

extension TheProduct: Comparable {
    public static func < (lhs: TheProduct, rhs: TheProduct) -> Bool {
        lhs.type.rawValue < rhs.type.rawValue
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

extension SKProductSubscriptionPeriod {
    func localizedPeriod() -> String? {
        return PeriodFormatter.format(unit: unit.toCalendarUnit(), numberOfUnits: numberOfUnits)
    }
}
