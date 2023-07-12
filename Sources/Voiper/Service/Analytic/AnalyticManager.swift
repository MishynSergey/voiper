
import Foundation
import FacebookCore
import Amplitude
import YandexMobileMetrica

public class AnalyticManager {
    
    public static let shared = AnalyticManager()
    private init() {}
    

    private var hasAvailableFacebook: Bool {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let bundle = dict["FacebookAppID"] as? String {
            print("MY LOG: \(bundle)")
        return true
        } else {
           return false
        }
    }
    
    private var amplToken: String? {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let bundle = dict["AmplitudeKey"] as? String {
        return bundle
        } else {
           return nil
        }
    }
    
    private var yandexToken: String? {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let bundle = dict["YandexKey"] as? String {
        return bundle
        } else {
           return nil
        }
    }
    
    
    func setupAnalytic() {
        if let amplToken = amplToken {
            Amplitude.instance().trackingSessionEvents = true
            Amplitude.instance().initializeApiKey(amplToken)
        }
        
        if let yandexToken  = yandexToken {
            if let config = YMMYandexMetricaConfiguration(apiKey: yandexToken) {
                YMMYandexMetrica.activate(with: config)
            }
        }
    }

    func setUserProperties(_ properties: [String: String]) {
        if amplToken != nil {
            Amplitude.instance().setUserProperties(properties)
        }
    }
    
    public func trackEvent(_ eventName: String, attributes: [String: Any] = [:]) {
        
        if hasAvailableFacebook {
            var fbParams: [AppEvents.ParameterName: Any] = [:]
            attributes.forEach { key, value in
                fbParams[.init(key)] = value
            }
            AppEvents.shared.logEvent(AppEvents.Name(eventName), parameters: fbParams)
        }
        if amplToken != nil {
            Amplitude.instance().logEvent(eventName, withEventProperties: attributes)
        }
        
        if yandexToken != nil {
            YMMYandexMetrica.reportEvent(eventName, parameters: attributes, onFailure: nil)
        }
        
        
    }
}
