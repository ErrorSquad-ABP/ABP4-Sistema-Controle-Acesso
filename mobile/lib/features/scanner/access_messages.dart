import 'access_contract.dart';

/// Textos da tela de resultado. O `message` que o backend devolve é técnico
/// (`Acesso negado: OUT_OF_RANGE`), então a tela escreve o seu a partir do
/// motivo. `summary` é a linha curta sob o título; `guidance`, o que fazer.
extension DenialReasonText on DenialReason {
  String get summary => switch (this) {
    DenialReason.invalidCredential => 'QR inválido para este terminal',
    DenialReason.credentialExpired => 'QR expirado',
    DenialReason.userInactive => 'Conta desativada — procure a portaria',
    DenialReason.noAuthorization =>
      'Sem autorização para este local — procure a portaria',
    DenialReason.authorizationNotStarted => 'Autorização ainda não começou',
    DenialReason.authorizationExpired =>
      'Autorização expirada — procure a portaria',
    DenialReason.authorizationCanceled =>
      'Autorização cancelada — procure a portaria',
    DenialReason.noUsesLeft => 'Sem usos restantes — procure a portaria',
    DenialReason.outOfRange => 'Você está longe do terminal',
    DenialReason.unknownTerminal => 'Terminal não reconhecido',
    DenialReason.terminalInactive => 'Terminal desativado',
    DenialReason.unknown => 'Não foi possível liberar o acesso',
  };

  String get guidance => switch (this) {
    DenialReason.invalidCredential =>
      'Escaneie o QR exibido no terminal à sua frente.',
    DenialReason.credentialExpired =>
      'O QR muda a cada 20 segundos. Aponte a câmera para o QR atualizado do '
          'terminal e tente de novo.',
    DenialReason.userInactive =>
      'Seu cadastro está inativo. Procure a administração para regularizar o '
          'acesso.',
    DenialReason.noAuthorization =>
      'Não encontramos uma autorização sua para este local. Solicite uma '
          'liberação na portaria.',
    DenialReason.authorizationNotStarted =>
      'Sua autorização ainda não está no período de uso. Volte quando a janela '
          'de acesso começar.',
    DenialReason.authorizationExpired =>
      'A janela de acesso terminou. Solicite uma nova liberação na portaria '
          'para continuar.',
    DenialReason.authorizationCanceled =>
      'Esta autorização foi cancelada. Solicite uma nova liberação na '
          'portaria.',
    DenialReason.noUsesLeft =>
      'Os acessos desta autorização acabaram. Solicite uma nova liberação na '
          'portaria.',
    DenialReason.outOfRange =>
      'O acesso só é liberado a até 100 metros do terminal. Aproxime-se e '
          'escaneie de novo.',
    DenialReason.unknownTerminal =>
      'Este terminal não está cadastrado. Avise a portaria.',
    DenialReason.terminalInactive =>
      'Este terminal ou local está desativado no momento. Procure a portaria.',
    DenialReason.unknown =>
      'Tente escanear de novo. Se continuar, procure a portaria.',
  };
}
