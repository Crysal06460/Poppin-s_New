import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configuration Firebase
    FirebaseApp.configure()
    
    // Configuration des notifications push
    if #available(iOS 10.0, *) {
      // Pour iOS 10+
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            print("✅ Notifications autorisées")
          } else {
            print("❌ Notifications refusées: \(error?.localizedDescription ?? "Erreur inconnue")")
          }
        })
    } else {
      // Pour iOS 9 et antérieur
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    // Enregistrer pour les notifications à distance
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // IMPORTANT: Gestion du token APNS
  override func application(_ application: UIApplication, 
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("📱 Token APNS reçu")
    
    // Définir le token APNS pour Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
    
    // Appeler la méthode parent
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Gestion des erreurs d'enregistrement
  override func application(_ application: UIApplication, 
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Échec enregistrement notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // Override des méthodes UNUserNotificationCenterDelegate déjà présentes dans FlutterAppDelegate
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
    let userInfo = notification.request.content.userInfo
    print("📨 Notification reçue en foreground: \(userInfo)")
    
    // Afficher la notification même si l'app est en foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    
    let userInfo = response.notification.request.content.userInfo
    print("🔔 Notification cliquée: \(userInfo)")
    
    // Appeler la méthode parent pour laisser Flutter gérer aussi
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}