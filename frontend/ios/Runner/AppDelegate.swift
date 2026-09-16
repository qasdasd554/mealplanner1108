import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Nie rejestrujemy APNs ręcznie podczas natywnego startu. W tym
    // momencie domyślna aplikacja Firebase może jeszcze nie istnieć, a
    // szybki zwrot zapamiętanego tokenu APNs wywoływał FirebaseMessaging
    // przed Firebase.initializeApp() i mógł zatrzymać start na białym
    // ekranie. Plugin firebase_messaging wykona rejestrację bezpiecznie
    // po inicjalizacji i po uzyskaniu zgody użytkownika.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
