package br.fatec.errorsquad.controle_acesso

object NfcCredentialStore {
    @Volatile
    private var token: String? = null

    fun set(value: String) {
        token = value
    }

    fun clear() {
        token = null
    }

    fun current(): String? = token
}
