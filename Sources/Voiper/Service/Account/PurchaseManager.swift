//
//  PurchaseManager.swift
//  
//
//  Created by Andrei (Work) on 26/07/2023.
//

import Foundation
import StoreKit
import PromiseKit

public class PurchaseManager: NSObject {
    public static let shared = PurchaseManager()
    public var products = Set<TheProduct>()

    public struct PurchaseResult {
        var reciept: String
        var price: String
        var currency: String
    }

    public typealias Completion = (Swift.Result<Set<String>, SKError>) -> Void
    
    public var receipt: String? {
        
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
            FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                let receiptString = receiptData.base64EncodedString(options: [])
                return receiptString
            }
            catch {
                print("Couldn't read receipt data: " + error.localizedDescription) }
        }
        
        return Date().description
    }
    
    private var requests: Set<ProductsRequest> = []
    
    private var fetchingCompletions = [String: Completion]()

    private var restoreCompletion: Completion?
    private var restoredProductIds = Set<String>()

    private var observeHandler: ((SKProduct) -> Void)?
    private var purchaseCompletions = [String: Completion]()

    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    public func observePurchases(handler: @escaping ((SKProduct) -> Void)) {
        observeHandler = handler
    }
    
    public func buyPoduct(_ product: TheProduct, completion: @escaping (Swift.Result<PurchaseResult, ServiceError>) -> Void) {
        purchaseProduct(product) { [weak self] purchaseResult in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(ServiceError.undefined))
                }
                return
            }
    
            switch purchaseResult {
            case .success(let IDs):
                guard IDs.contains(product.skProduct.productIdentifier) else { return }

                guard let receipt = self.receipt else {
                    DispatchQueue.main.async {
                        completion(.failure(ServiceError.undefined))
                    }
                    return
                }
                DispatchQueue.main.async {
                    completion(.success(PurchaseResult(reciept: receipt, price: "\(product.skProduct.price)",
                                                       currency: product.currency)))
                }

            case .failure(let skError):
                DispatchQueue.main.async {
                    completion(.failure(.purchaseError(skError.localizedDescription)))
                }
            }
            
        }
    }
    
    public func purchaseProduct(_ product: TheProduct, completion: @escaping Completion) {
        purchaseCompletions[product.skProduct.productIdentifier] = completion
        SKPaymentQueue.default().add(SKPayment(product: product.skProduct))
    }
    
    public func fetchProducts(_ productTypes: Set<String>, completion: Completion? = nil) {
        let prefetchedProducts = products.compactMap { productTypes.contains($0.skProduct.productIdentifier) ? $0 : nil }
        if prefetchedProducts.count == productTypes.count {
            DispatchQueue.main.async {
                completion?(.success(Set(prefetchedProducts.compactMap { $0.skProduct.productIdentifier } )))
            }
        } else {
            let request = ProductsRequest(productIdentifiers: Set(productTypes))
            request.id = "\(Date.timeIntervalSinceReferenceDate)"
            fetchingCompletions[request.id] = completion
            request.delegate = self
            requests.insert(request)
            request.start()
        }
    }
    
    public func restorePurchases(completion: Completion? = nil) {
        DispatchQueue.main.async {
            self.restoreCompletion = completion
            self.restoredProductIds.removeAll()
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }
}

fileprivate extension PurchaseManager {
    class ProductsRequest: SKProductsRequest {
        var id = ""
    }
}

extension PurchaseManager: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        guard let request = request as? ProductsRequest else { return }
        response.products.forEach { products.insert(TheProduct(with: $0)) }
        DispatchQueue.main.async {
            if response.invalidProductIdentifiers.isEmpty {
                self.fetchingCompletions[request.id]?(.success(Set(response.products.map { $0.productIdentifier })))
            } else {
                print(response.invalidProductIdentifiers)
                self.fetchingCompletions[request.id]?(.failure(SKError.init(SKError.unknown, userInfo: [:])))
            }
            self.fetchingCompletions[request.id] = nil
            self.requests.remove(request)
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        guard let request = request as? ProductsRequest, let error = error as? SKError else { return }
        DispatchQueue.main.async {
            self.fetchingCompletions[request.id]?(.failure(error))
            self.fetchingCompletions[request.id] = nil
        }
    }
}

extension PurchaseManager: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let id = transaction.payment.productIdentifier
            var result: Swift.Result<Set<String>, SKError>?
            switch transaction.transactionState {
            case .purchased:
                queue.finishTransaction(transaction)
                result = .success([id])
            case .restored:
                queue.finishTransaction(transaction)
                restoredProductIds.insert(id)
                if restoreCompletion == nil {
                    result = .success([id]) // if we're buying second time
                }
            case .failed:
                queue.finishTransaction(transaction)
                guard let error = transaction.error as? SKError else { break }
                result = .failure(error)
            case .deferred:
                break
            default:
                break
            }
            if let result = result, let product = products.first(where: { $0.skProduct.productIdentifier == id }) {
                DispatchQueue.main.async {
                    self.observeHandler?(product.skProduct)
                    self.purchaseCompletions[id]?(result)
                    self.purchaseCompletions[id] = nil
                }
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.async {
            self.restoreCompletion?(.success(self.restoredProductIds))
            self.restoreCompletion = nil
            self.restoredProductIds.removeAll()
        }
    }

    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        guard let error = error as? SKError else { return }
        DispatchQueue.main.async {
            self.restoreCompletion?(.failure(error))
            self.restoreCompletion = nil
            self.restoredProductIds.removeAll()
        }
    }
}

extension SKError.Code: CustomStringConvertible {
    public var description: String {
        switch self {
        case .clientInvalid:
            return "clientInvalid".localized
        case .cloudServiceNetworkConnectionFailed:
            return "cloudServiceNetworkConnectionFailed".localized
        case .cloudServicePermissionDenied:
            return "cloudServicePermissionDenied".localized
        case .paymentCancelled:
            return "paymentCancelled".localized
        case .paymentInvalid:
            return "paymentInvalid".localized
        case .paymentNotAllowed:
            return "paymentNotAllowed".localized
        case .storeProductNotAvailable:
            return "storeProductNotAvailable".localized
        default:
            return "unknown".localized
        }
    }
}
