/**
 * Regra unica do `terminalId` no backend: topicos MQTT, contrato REST e config
 * leem daqui. 1 a 64 caracteres, minusculas/numeros/hifen, comecando por
 * alfanumerico (sem separador ou wildcard, para nao quebrar o topico).
 */
export const TERMINAL_ID_PATTERN = /^[a-z0-9][a-z0-9-]{0,63}$/;
