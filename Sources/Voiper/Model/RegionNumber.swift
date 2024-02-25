

import Foundation

public struct RegionNumbersResponse: Decodable {
    public let numbers: [RegionNumber]
}

extension RegionNumbersResponse: CustomStringConvertible {
    public var description: String {
        return jsonFormatDescription((name: "numbers", value: numbers.description))
    }
}

public struct RegionNumber: Decodable {
    public let region: String?
    public let formattedNumber: String
    public let number: String
    public let country: String
    public let capabilities: [Capability]
    public let addressRequired: Int
    public let renewPrice: Int
    public let source: Source?
    public let note: String?
    let provider: NumberProvider
    
    public var isAddressRequired: Bool {
         return addressRequired > 0
    }
    
    public enum AddressRequiredType: Int {
        case none
        case any
        case local
        case foreign
    }
    
    public enum CodingKeys: String, CodingKey {
        case region
        case formattedNumber =  "number_friendly"
        case number
        case country
        case capabilities
        case addressRequired =  "address_required"
        case renewPrice =       "renew_price_cr"
        case source
        case note
        case provider
    }
    
    public init(region: String?, formattedNumber: String, number: String, country: String, capabilities: [Capability], addressRequired: Int, renewPrice: Int, source: Source?, note: String, provider: NumberProvider) {
        self.region = region
        self.formattedNumber = formattedNumber
        self.number = number
        self.country = country
        self.capabilities = capabilities
        self.addressRequired = addressRequired
        self.renewPrice = renewPrice
        self.source = source
        self.note = note
        self.provider = provider
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
        self.formattedNumber = try container.decode(String.self, forKey: .formattedNumber)
        self.number = try container.decode(String.self, forKey: .number)
        self.country = try container.decode(String.self, forKey: .country)
        self.capabilities = try container.decode([Capability].self, forKey: .capabilities)
        self.addressRequired = try container.decode(Int.self, forKey: .addressRequired)
        self.renewPrice = try container.decodeIfPresent(Int.self, forKey: .renewPrice) ?? 0
        self.source = try container.decodeIfPresent(RegionNumber.Source.self, forKey: .source)
        self.note = try container.decode(String.self, forKey: .note)
        self.provider = try container.decode(NumberProvider.self, forKey: .provider)
    }
}

extension RegionNumber {
    public enum Source: String, Decodable {
        case pool
        case twilio
        case telnyx
        case unknown
        
        public init(rawValue: String?) {
            switch rawValue?.lowercased() {
            case "pool":
                self = .pool
            case "twilio":
                self = .twilio
            case "telnyx":
                self = .telnyx
            default:
                self = .unknown
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self = Source(rawValue: try? container.decode(String.self))
        }
    }
}

extension RegionNumber: CustomStringConvertible {
    public var description: String {
        return jsonFormatDescription((name: "region", value: region ?? ""),
                                     (name: "number", value: number),
                                     (name: "formattedNumber", value: formattedNumber),
                                     (name: "country", value: country),
                                     (name: "capabilities", value: capabilities.description),
                                     (name: "addressRequired", value: String(addressRequired)),
                                     (name: "renewPrice", value: String(renewPrice)))
    }
}
