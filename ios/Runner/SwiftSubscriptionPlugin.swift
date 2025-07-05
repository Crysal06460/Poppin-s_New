// ios/Runner/SwiftSubscriptionPlugin.swift
import Flutter
import StoreKit
import Foundation

@available(iOS 13.0, *)
public class SwiftSubscriptionPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel
    private var paymentQueue: SKPaymentQueue
    private var productsRequest: SKProductsRequest?
    private var availableProducts: [SKProduct] = []
    private var pendingResult: FlutterResult?
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        self.paymentQueue = SKPaymentQueue.default()
        super.init()
        self.paymentQueue.add(self)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ios_subscription", binaryMessenger: registrar.messenger())
        let instance = SwiftSubscriptionPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeStoreKit(call, result: result)
        case "purchaseProduct":
            purchaseProduct(call, result: result)
        case "restorePurchases":
            restorePurchases(result: result)
        case "checkSubscriptionStatus":
            checkSubscriptionStatus(result: result)
        case "getProductsInfo":
            getProductsInfo(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeStoreKit(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let productIds = args["productIds"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Product IDs required", details: nil))
            return
        }
        
        print("🍎 Initialisation StoreKit avec produits: \(productIds)")
        
        // Vérifier si les achats sont autorisés
        guard SKPaymentQueue.canMakePayments() else {
            result(FlutterError(code: "PAYMENTS_DISABLED", message: "Achats désactivés sur cet appareil", details: nil))
            return
        }
        
        // Charger les produits
        loadProducts(productIds: productIds) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    result(["status": "success", "productsCount": self?.availableProducts.count ?? 0])
                } else {
                    result(FlutterError(code: "INIT_FAILED", message: "Échec chargement produits", details: nil))
                }
            }
        }
    }
    
    private func loadProducts(productIds: [String], completion: @escaping (Bool) -> Void) {
        let productIdentifiers = Set(productIds)
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
        
        // Store completion for later use
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            completion(!self.availableProducts.isEmpty)
        }
    }
    
    private func purchaseProduct(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let productId = args["productId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Product ID required", details: nil))
            return
        }
        
        print("🛒 Achat demandé pour: \(productId)")
        
        guard let product = availableProducts.first(where: { $0.productIdentifier == productId }) else {
            result(FlutterError(code: "PRODUCT_NOT_FOUND", message: "Produit non trouvé: \(productId)", details: nil))
            return
        }
        
        let payment = SKPayment(product: product)
        paymentQueue.add(payment)
        
        pendingResult = result
    }
    
    private func restorePurchases(result: @escaping FlutterResult) {
        print("🔄 Restauration des achats...")
        paymentQueue.restoreCompletedTransactions()
        pendingResult = result
    }
    
    private func checkSubscriptionStatus(result: @escaping FlutterResult) {
        print("🔍 Vérification statut abonnement...")
        
        // Cette méthode nécessite iOS 15+ pour l'API StoreKit 2
        if #available(iOS 15.0, *) {
            checkCurrentEntitlements(result: result)
        } else {
            // Fallback pour iOS plus anciens
            checkLegacySubscriptions(result: result)
        }
    }
    
    @available(iOS 15.0, *)
    private func checkCurrentEntitlements(result: @escaping FlutterResult) {
        Task {
            do {
                // Utiliser StoreKit 2 pour vérifier les abonnements actuels
                for await renewalInfo in Transaction.currentEntitlements {
                    if case .verified(let transaction) = renewalInfo {
                        print("✅ Abonnement actif trouvé: \(transaction.productID)")
                        
                        let subscriptionInfo: [String: Any] = [
                            "isActive": true,
                            "productId": transaction.productID,
                            "originalTransactionId": transaction.originalID,
                            "purchaseDate": ISO8601DateFormatter().string(from: transaction.purchaseDate),
                            "expirationDate": transaction.expirationDate != nil ? 
                                ISO8601DateFormatter().string(from: transaction.expirationDate!) : nil
                        ]
                        
                        DispatchQueue.main.async {
                            result(subscriptionInfo)
                        }
                        return
                    }
                }
                
                // Aucun abonnement actif
                DispatchQueue.main.async {
                    result(["isActive": false])
                }
            } catch {
                print("❌ Erreur vérification abonnements: \(error)")
                DispatchQueue.main.async {
                    result(FlutterError(code: "CHECK_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func checkLegacySubscriptions(result: @escaping FlutterResult) {
        // Pour iOS < 15, on utilise une approche plus basique
        // En pratique, vous devriez vérifier avec votre serveur backend
        print("⚠️ Vérification legacy - recommandé de vérifier côté serveur")
        result(["isActive": false, "legacy": true])
    }
    
    private func getProductsInfo(result: @escaping FlutterResult) {
        let productsInfo = availableProducts.map { product in
            return [
                "productId": product.productIdentifier,
                "title": product.localizedTitle,
                "description": product.localizedDescription,
                "price": formatPrice(product.price, locale: product.priceLocale),
                "currencyCode": product.priceLocale.currencyCode ?? "EUR"
            ]
        }
        
        result(productsInfo)
    }
    
    private func formatPrice(_ price: NSDecimalNumber, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: price) ?? "\(price)"
    }
    
    private func sendPurchaseResult(success: Bool, transaction: SKPaymentTransaction? = nil, error: Error? = nil) {
        guard let result = pendingResult else { return }
        
        if success, let transaction = transaction {
            let purchaseData: [String: Any] = [
                "productId": transaction.payment.productIdentifier,
                "transactionId": transaction.transactionIdentifier ?? "",
                "purchaseDate": ISO8601DateFormatter().string(from: transaction.transactionDate ?? Date()),
                "originalTransactionId": transaction.original?.transactionIdentifier ?? ""
            ]
            
            channel.invokeMethod("onPurchaseSuccess", arguments: purchaseData)
            result(purchaseData)
        } else if let error = error {
            let errorData: [String: Any] = [
                "message": error.localizedDescription,
                "code": (error as NSError).code
            ]
            
            channel.invokeMethod("onPurchaseError", arguments: errorData)
            result(FlutterError(code: "PURCHASE_ERROR", message: error.localizedDescription, details: nil))
        }
        
        pendingResult = nil
    }
}

// MARK: - SKProductsRequestDelegate
@available(iOS 13.0, *)
extension SwiftSubscriptionPlugin: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        print("📦 Produits reçus: \(response.products.count)")
        
        availableProducts = response.products
        
        for product in response.products {
            print("✅ Produit disponible: \(product.productIdentifier) - \(product.localizedTitle)")
        }
        
        if !response.invalidProductIdentifiers.isEmpty {
            print("❌ Produits invalides: \(response.invalidProductIdentifiers)")
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("❌ Erreur chargement produits: \(error.localizedDescription)")
        availableProducts = []
    }
}

// MARK: - SKPaymentTransactionObserver
@available(iOS 13.0, *)
extension SwiftSubscriptionPlugin: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            handleTransaction(transaction)
        }
    }
    
    private func handleTransaction(_ transaction: SKPaymentTransaction) {
        print("📱 Transaction mise à jour: \(transaction.payment.productIdentifier) - \(transaction.transactionState.rawValue)")
        
        switch transaction.transactionState {
        case .purchased:
            print("✅ Achat réussi: \(transaction.payment.productIdentifier)")
            handleSuccessfulPurchase(transaction)
            paymentQueue.finishTransaction(transaction)
            
        case .restored:
            print("🔄 Achat restauré: \(transaction.payment.productIdentifier)")
            handleRestoredPurchase(transaction)
            paymentQueue.finishTransaction(transaction)
            
        case .failed:
            print("❌ Achat échoué: \(transaction.error?.localizedDescription ?? "Erreur inconnue")")
            handleFailedPurchase(transaction)
            paymentQueue.finishTransaction(transaction)
            
        case .deferred:
            print("⏳ Achat en attente d'autorisation")
            // Ne pas finir la transaction, elle sera mise à jour plus tard
            
        case .purchasing:
            print("🔄 Achat en cours...")
            // Transaction en cours, ne rien faire
            
        @unknown default:
            print("⚠️ État de transaction inconnu")
            paymentQueue.finishTransaction(transaction)
        }
    }
    
    private func handleSuccessfulPurchase(_ transaction: SKPaymentTransaction) {
        let purchaseData: [String: Any] = [
            "productId": transaction.payment.productIdentifier,
            "transactionId": transaction.transactionIdentifier ?? "",
            "purchaseDate": ISO8601DateFormatter().string(from: transaction.transactionDate ?? Date()),
            "originalTransactionId": transaction.original?.transactionIdentifier ?? ""
        ]
        
        channel.invokeMethod("onPurchaseSuccess", arguments: purchaseData)
        
        if let result = pendingResult {
            result(purchaseData)
            pendingResult = nil
        }
    }
    
    private func handleRestoredPurchase(_ transaction: SKPaymentTransaction) {
        let purchaseData: [String: Any] = [
            "productId": transaction.payment.productIdentifier,
            "transactionId": transaction.transactionIdentifier ?? "",
            "purchaseDate": ISO8601DateFormatter().string(from: transaction.transactionDate ?? Date()),
            "originalTransactionId": transaction.original?.transactionIdentifier ?? "",
            "restored": true
        ]
        
        // Notifier la restauration
        channel.invokeMethod("onPurchaseSuccess", arguments: purchaseData)
    }
    
    private func handleFailedPurchase(_ transaction: SKPaymentTransaction) {
        let error = transaction.error as NSError?
        let errorCode = error?.code ?? -1
        
        if errorCode == SKError.paymentCancelled.rawValue {
            channel.invokeMethod("onPurchaseCanceled", arguments: nil)
            if let result = pendingResult {
                result(FlutterError(code: "USER_CANCELLED", message: "Achat annulé par l'utilisateur", details: nil))
                pendingResult = nil
            }
        } else {
            let errorData: [String: Any] = [
                "message": error?.localizedDescription ?? "Erreur inconnue",
                "code": errorCode
            ]
            
            channel.invokeMethod("onPurchaseError", arguments: errorData)
            if let result = pendingResult {
                result(FlutterError(code: "PURCHASE_FAILED", message: error?.localizedDescription ?? "Erreur inconnue", details: nil))
                pendingResult = nil
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("✅ Restauration terminée")
        channel.invokeMethod("onRestoreComplete", arguments: [])
        
        if let result = pendingResult {
            result(["restored": true])
            pendingResult = nil
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("❌ Échec restauration: \(error.localizedDescription)")
        
        if let result = pendingResult {
            result(FlutterError(code: "RESTORE_FAILED", message: error.localizedDescription, details: nil))
            pendingResult = nil
        }
    }
}
