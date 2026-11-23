package br.fatec.errorsquad.controle_acesso

import android.nfc.NfcAdapter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "abp4/nfc")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(
                        NfcAdapter.getDefaultAdapter(this) != null &&
                            packageManager.hasSystemFeature(
                                android.content.pm.PackageManager.FEATURE_NFC_HOST_CARD_EMULATION,
                            ),
                    )
                    "setToken" -> {
                        val token = call.argument<String>("token")
                        if (token == null || !Regex("^[0-9a-f]{32}$").matches(token)) {
                            result.error("INVALID_TOKEN", "prova de NFC invalida", null)
                        } else {
                            NfcCredentialStore.set(token)
                            result.success(null)
                        }
                    }
                    "clearToken" -> {
                        NfcCredentialStore.clear()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
