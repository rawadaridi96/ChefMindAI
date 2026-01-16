package com.example.chefmind_ai

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.chefmind_ai/share"
    private var sharedText: String? = null
    private var methodChannel: io.flutter.plugin.common.MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            if (call.method == "getSharedText") {
                result.success(sharedText)
                sharedText = null // Clear after reading once
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val intent = getIntent()
            handleIntent(intent)
        } catch (e: Exception) {
            android.util.Log.e("ChefMindDebug", "Error in onCreate", e)
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        try {
            handleIntent(intent)
        } catch (e: Exception) {
            android.util.Log.e("ChefMindDebug", "Error in onNewIntent", e)
        }
    }

    private fun handleIntent(intent: android.content.Intent) {
        android.util.Log.e("ChefMindDebug", "Action=${intent.action}, Type=${intent.type}")
        if (android.content.Intent.ACTION_SEND == intent.action && "text/plain" == intent.type) {
            intent.getStringExtra(android.content.Intent.EXTRA_TEXT)?.let { text ->
                android.util.Log.e("ChefMindDebug", "Shared Text: $text")
                sharedText = text
                methodChannel?.invokeMethod("shareText", text)
            }
        }
    }
}
