import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/access_messages.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _result({
  Object? decision = 'GRANTED',
  Object? reason,
  Object? event,
}) => {
  'decision': decision,
  'reason': reason,
  'message': 'texto técnico do backend',
  'event':
      event ??
      {
        'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
        'occurredAt': '2026-10-27T17:32:10.000Z',
        'terminalId': 'terminal-01',
        'method': 'QR',
        'decision': decision,
        'reason': reason,
        'location': {
          'id': '5b0b1f8e-0f4f-4d0e-8d1f-9a4f5a6c7d8e',
          'name': 'Edifício Aurora · Recepção',
        },
        'distanceMeters': 12.4,
      },
};

void main() {
  group('terminalIdFromQrToken', () {
    test('lê o terminal do token no formato do backend', () {
      expect(
        terminalIdFromQrToken('v1.terminal-01.1790000000.1790000010.AbC-_9'),
        'terminal-01',
      );
      expect(
        terminalIdFromQrToken('  v1.aurora-recepcao.1.11.sig  '),
        'aurora-recepcao',
      );
    });

    for (final (nome, token) in [
      ('texto qualquer', 'QR-1234'),
      ('vazio', ''),
      ('versão diferente', 'v2.terminal-01.1.11.sig'),
      ('partes a menos', 'v1.terminal-01.1.11'),
      ('partes a mais', 'v1.terminal-01.1.11.sig.extra'),
      ('terminal vazio', 'v1..1.11.sig'),
      ('terminal com maiúscula', 'v1.Terminal-01.1.11.sig'),
      ('terminal com espaço', 'v1.terminal 01.1.11.sig'),
      ('terminal começando por hífen', 'v1.-terminal.1.11.sig'),
      ('terminal acima de 64 caracteres', 'v1.${'a' * 65}.1.11.sig'),
      ('URL', 'https://exemplo.com/qr'),
    ]) {
      test('recusa $nome', () {
        expect(terminalIdFromQrToken(token), isNull);
      });
    }

    test('aceita terminal de 64 caracteres', () {
      expect(terminalIdFromQrToken('v1.${'a' * 64}.1.11.sig'), 'a' * 64);
    });
  });

  group('QrAccessRequest.toJson', () {
    test('monta o corpo do contrato com a precisão quando existe', () {
      const request = QrAccessRequest(
        qrToken: 'v1.terminal-01.1.11.sig',
        terminalId: 'terminal-01',
        position: GeoCoordinate(
          latitude: -23.1857,
          longitude: -45.8846,
          accuracyMeters: 12,
        ),
        requestId: '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
      );

      expect(request.toJson(), {
        'qrToken': 'v1.terminal-01.1.11.sig',
        'terminalId': 'terminal-01',
        'position': {
          'latitude': -23.1857,
          'longitude': -45.8846,
          'accuracyMeters': 12,
        },
        'requestId': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
      });
    });

    test('omite a precisão quando o GPS não informou', () {
      const request = QrAccessRequest(
        qrToken: 't',
        terminalId: 'terminal-01',
        position: GeoCoordinate(latitude: 1, longitude: 2),
        requestId: 'r',
      );

      expect(
        (request.toJson()['position']! as Map<String, Object>).containsKey(
          'accuracyMeters',
        ),
        isFalse,
      );
    });
  });

  group('AccessResult.fromJson', () {
    test('liberado: local e horário do evento, sem motivo', () {
      final result = AccessResult.fromJson(_result());

      expect(result.decision, AccessDecision.granted);
      expect(result.reason, isNull);
      expect(result.locationName, 'Edifício Aurora · Recepção');
      expect(result.occurredAt, DateTime.utc(2026, 10, 27, 17, 32, 10));
      expect(result.occurredAt.isUtc, isTrue);
    });

    test('negado: traz o motivo do contrato', () {
      final result = AccessResult.fromJson(
        _result(decision: 'DENIED', reason: 'OUT_OF_RANGE'),
      );

      expect(result.decision, AccessDecision.denied);
      expect(result.reason, DenialReason.outOfRange);
    });

    test('motivo desconhecido ou ausente vira texto genérico, não erro', () {
      expect(
        AccessResult.fromJson(
          _result(decision: 'DENIED', reason: 'MOTIVO_NOVO'),
        ).reason,
        DenialReason.unknown,
      );
      expect(
        AccessResult.fromJson(_result(decision: 'DENIED')).reason,
        DenialReason.unknown,
      );
    });

    test('negado sem local (terminal desconhecido) ainda é lido', () {
      final result = AccessResult.fromJson(
        _result(
          decision: 'DENIED',
          reason: 'UNKNOWN_TERMINAL',
          event: {'occurredAt': '2026-10-27T17:32:10.000Z', 'location': null},
        ),
      );

      expect(result.locationName, isNull);
      expect(result.reason, DenialReason.unknownTerminal);
    });

    test('ignora o motivo quando liberado', () {
      expect(
        AccessResult.fromJson(_result(reason: 'OUT_OF_RANGE')).reason,
        isNull,
      );
    });

    for (final (nome, json) in [
      ('decisão desconhecida', _result(decision: 'TALVEZ')),
      ('decisão ausente', _result(decision: null)),
      ('evento ausente', {'decision': 'GRANTED', 'reason': null}),
      ('evento sem data', _result(event: {'location': null})),
      (
        'data ilegível',
        _result(event: {'occurredAt': 'ontem', 'location': null}),
      ),
    ]) {
      test('recusa $nome', () {
        expect(() => AccessResult.fromJson(json), throwsFormatException);
      });
    }
  });

  group('DenialReason', () {
    test('lê cada código do contrato', () {
      for (final reason in DenialReason.values) {
        if (reason == DenialReason.unknown) continue;
        expect(DenialReason.fromCode(reason.code), reason);
      }
      expect(DenialReason.fromCode('OUT_OF_RANGE'), DenialReason.outOfRange);
      expect(DenialReason.fromCode(null), DenialReason.unknown);
      expect(DenialReason.fromCode(''), DenialReason.unknown);
    });

    test('cobre os 11 motivos do contrato v1', () {
      expect(
        DenialReason.values.where((r) => r != DenialReason.unknown).length,
        11,
      );
    });

    test('todo motivo tem texto em português, sem expor o código', () {
      for (final reason in DenialReason.values) {
        expect(reason.summary, isNotEmpty, reason: '$reason');
        expect(reason.guidance, isNotEmpty, reason: '$reason');
        if (reason.code.isNotEmpty) {
          expect(reason.summary, isNot(contains(reason.code)));
          expect(reason.guidance, isNot(contains(reason.code)));
        }
      }
    });
  });
}
