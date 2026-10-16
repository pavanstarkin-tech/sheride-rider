package com.sheride.rider

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sheride.rider/pip"
    private var isPipAllowed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val entered = triggerPip()
                    result.success(entered)
                }
                "setPipAllowed" -> {
                    isPipAllowed = call.argument<Boolean>("allowed") ?: false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun triggerPip(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val aspectRatio = Rational(16, 9)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    .build()
                return enterPictureInPictureMode(params)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return false
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isPipAllowed) {
            triggerPip()
        }
    }
}
