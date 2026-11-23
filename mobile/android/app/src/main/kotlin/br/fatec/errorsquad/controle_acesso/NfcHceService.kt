package br.fatec.errorsquad.controle_acesso

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * Emula o cartao ISO-DEP do app. Devolve a prova efemera mantida em memoria;
 * nunca e o UID do aparelho e nao concede acesso sozinha.
 */
class NfcHceService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null || !commandApdu.contentEquals(SELECT_AID)) {
            return UNKNOWN
        }
        val token = NfcCredentialStore.current() ?: return NO_CREDENTIAL
        if (!Regex("^[0-9a-f]{32}$").matches(token)) return NO_CREDENTIAL
        return token.toByteArray(Charsets.US_ASCII) + STATUS_OK
    }

    override fun onDeactivated(reason: Int) {}

    companion object {
        private val STATUS_OK = byteArrayOf(0x90.toByte(), 0x00)
        private val NO_CREDENTIAL = byteArrayOf(0x69.toByte(), 0x85.toByte())
        private val UNKNOWN = byteArrayOf(0x6A.toByte(), 0x82.toByte())
        private val SELECT_AID = byteArrayOf(
            0x00, 0xA4.toByte(), 0x04, 0x00, 0x08,
            0xF0.toByte(), 0x41, 0x42, 0x50, 0x34, 0x44, 0x4D, 0x01, 0x00,
        )
    }
}
