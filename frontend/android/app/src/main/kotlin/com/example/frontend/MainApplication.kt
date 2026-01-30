package com.example.frontend

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey("76680787-ebd4-43fd-861b-11494d191834")
    }
}
