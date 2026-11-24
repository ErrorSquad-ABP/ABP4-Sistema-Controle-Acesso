package br.fatec.errorsquad.controle_acesso

import android.content.ComponentName
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cardEmulation by lazy {
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)) {
            NfcAdapter.getDefaultAdapter(this)?.let { CardEmulation.getInstance(it) }
        } else {
            null
        }
    }
    private var resumed = false
    private var hcePreferred = false

    override fun onPostResume() {
        super.onPostResume()
        resumed = true
        updateHcePreference()
    }

    override fun onPause() {
        resumed = false
        updateHcePreference()
        super.onPause()
    }

    private fun updateHcePreference() {
        val shouldPrefer = resumed && NfcCredentialStore.current() != null
        if (shouldPrefer == hcePreferred) return

        if (shouldPrefer) {
            hcePreferred = cardEmulation?.setPreferredService(
                this,
                ComponentName(this, NfcHceService::class.java),
            ) == true
        } else {
            cardEmulation?.unsetPreferredService(this)
            hcePreferred = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "abp4/nfc")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(cardEmulation != null)
                    "setToken" -> {
                        val token = call.argument<String>("token")
                        if (token == null || !Regex("^[0-9a-f]{32}$").matches(token)) {
                            result.error("INVALID_TOKEN", "prova de NFC invalida", null)
                        } else {
                            NfcCredentialStore.set(token)
                            updateHcePreference()
                            result.success(null)
                        }
                    }
                    "clearToken" -> {
                        NfcCredentialStore.clear()
                        updateHcePreference()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
