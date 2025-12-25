package com.example.frontend

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.yandex.mapkit.MapKitFactory

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        // Pega tu API Key aquí abajo vvv
        MapKitFactory.setApiKey("76680787-ebd4-43fd-861b-11494d191834") 
        super.configureFlutterEngine(flutterEngine)
    }
}