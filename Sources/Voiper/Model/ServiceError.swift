

import Foundation

public enum ServiceError: Error {
    case notAuthorized
    case purchaseError(String)
    case undecodable
    case networkError(API, Int, String)
    case undefined
    case other(Error)
    case restoreUnavailable
    case accountPaused
    case phoneRestoring(String)
    case innactiveNumber
}
