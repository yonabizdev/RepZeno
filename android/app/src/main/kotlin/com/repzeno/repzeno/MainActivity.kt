package com.repzeno.repzeno

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val STORAGE_CHANNEL = "com.repzeno.repzeno/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "excludeFromBackup") {
                // On Android, backup exclusion is primarily handled via AndroidManifest.xml 
                // (allowBackup=false) and backup_rules.xml.
                // This MethodChannel exists for parity with iOS and granular future-proofing.
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
