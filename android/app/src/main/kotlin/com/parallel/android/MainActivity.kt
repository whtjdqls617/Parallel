package com.parallel.android

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        "parallel_traces",
        "Traces",
        NotificationManager.IMPORTANCE_DEFAULT,
      ).apply {
        description = "마음걸이 새 흔적"
      }
      val manager = getSystemService(NotificationManager::class.java)
      manager?.createNotificationChannel(channel)
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "parallel/badge",
    ).setMethodCallHandler { call, result ->
      if (call.method != "clear") {
        result.notImplemented()
        return@setMethodCallHandler
      }
      val manager = getSystemService(NotificationManager::class.java)
      manager?.cancelAll()
      result.success(null)
    }
  }
}
