import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushRegistrationChannel: FlutterMethodChannel?

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

    // Firebase jest inicjalizowany po pierwszej klatce Fluttera. Kanał
    // pozwala więc poprosić iOS o rejestrację w APNs dopiero wtedy, gdy
    // Firebase Messaging jest już gotowy do odebrania i powiązania tokenu.
    // Eliminuje to zarówno brak tokenu na iOS, jak i wcześniejszy biały
    // ekran powodowany rejestracją zbyt wcześnie podczas natywnego startu.
    let channel = FlutterMethodChannel(
      name: "com.meal-planner-polska-v1/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "registerForRemoteNotifications" else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      }
    }
    pushRegistrationChannel = channel
  }
}
