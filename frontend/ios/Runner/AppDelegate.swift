import UIKit
import Flutter
import YandexMapsMobile // <--- Importante

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pega tu API Key aquí abajo vvv
    YMKMapKit.setApiKey("76680787-ebd4-43fd-861b-11494d191834")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}