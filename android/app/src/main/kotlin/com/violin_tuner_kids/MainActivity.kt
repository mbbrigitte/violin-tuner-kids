package com.violin_tuner_kids

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.violin_tuner_kids.audio.AudioProcessor

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.violin_tuner_kids.tuner/audio"
    private var audioProcessor: AudioProcessor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        audioProcessor = AudioProcessor()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    audioProcessor?.startListening()
                    result.success(null)
                }
                "stopListening" -> {
                    audioProcessor?.stopListening()
                    result.success(null)
                }
                "getPitch" -> {
                    val pitch = audioProcessor?.currentPitch ?: 0.0
                    val amplitude = audioProcessor?.currentAmplitude ?: 0.0
                    result.success(mapOf("pitch" to pitch, "amplitude" to amplitude))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        audioProcessor?.stopListening()
    }
}