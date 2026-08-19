package com.example.smart_meal_planner

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Obsługa udostępnień z innych aplikacji (np. link do filmiku z TikToka
 * wysłany przez systemowe menu "Udostępnij") — WŁASNA, minimalna
 * implementacja przez MethodChannel, zamiast zewnętrznego pakietu.
 *
 * Powód: dwie kolejne biblioteki z pub.dev (receive_sharing_intent,
 * listen_receive_sharing_intent) miały problemy z budowaniem —
 * nieaktualne/niespójnie opublikowane paczki. Ten kod używa wyłącznie
 * stabilnego, wieloletniego API Androida (Intent) i Fluttera
 * (MethodChannel), bez zależności od jakiegokolwiek pakietu trzeciej
 * strony, więc nie ma ryzyka powtórki tego samego problemu.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.meal_planner_polska_v1/share_intent"
    private var methodChannel: MethodChannel? = null

    // Tekst udostępniony PRZED pełną inicjalizacją silnika Fluttera
    // (zimny start aplikacji przez samo udostępnienie, nie przez zwykłe
    // uruchomienie) — czekamy, aż strona Dart o niego zapyta.
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // UWAGA (naprawa): enableEdgeToEdge() z androidx.activity wymaga
        // odbiornika typu ComponentActivity — FlutterActivity NIM NIE
        // JEST (dziedziczy bezpośrednio po zwykłej Activity), stąd błąd
        // kompilacji "receiver type mismatch". WindowCompat to niżej
        // poziomowe API, które robi dokładnie to samo (wyłącza domyślne
        // "dopasowywanie" okna do systemowych pasków, czyli włącza
        // tryb "bez ramki"/edge-to-edge), ale działa z KAŻDĄ Activity,
        // nie tylko ComponentActivity — dlatego jest tu właściwym
        // wyborem zamiast wygodniejszej, ale niekompatybilnej funkcji.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        pendingSharedText = extractSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    result.success(pendingSharedText)
                    // Zwracamy tylko raz — kolejne zapytania (np. po hot
                    // restarcie w trakcie developmentu) nie powinny wciąż
                    // dostawać tego samego, już "zjedzonego" udostępnienia.
                    pendingSharedText = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val sharedText = extractSharedText(intent)
        if (sharedText != null) {
            // Aplikacja już działa w tle/na pierwszym planie — wypchnij
            // tekst bezpośrednio do Dart, zamiast czekać na zapytanie
            // (Dart nie ma jak "zapytać ponownie" w tym scenariuszu).
            methodChannel?.invokeMethod("onSharedText", sharedText)
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            return intent.getStringExtra(Intent.EXTRA_TEXT)
        }
        return null
    }
}
