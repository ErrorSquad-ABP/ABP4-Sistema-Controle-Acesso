import 'package:controle_acesso/features/admin_users/access_events_contract.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart'
    show AccessDecision, DenialReason;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('accessEventTimeLabel', () {
    final now = DateTime(2026, 10, 27, 18, 30);

    test('hoje mostra só a hora', () {
      expect(
        accessEventTimeLabel(
          occurredAt: DateTime(2026, 10, 27, 14, 32),
          now: now,
        ),
        'Hoje · 14:32',
      );
    });

    test('outro dia do mesmo ano mostra dia e mês', () {
      expect(
        accessEventTimeLabel(occurredAt: DateTime(2026, 1, 5, 8, 5), now: now),
        '05/01 · 08:05',
      );
    });

    test('outro ano mostra a data completa', () {
      expect(
        accessEventTimeLabel(
          occurredAt: DateTime(2025, 12, 31, 23, 59),
          now: now,
        ),
        '31/12/2025 · 23:59',
      );
    });
  });

  group('rótulos para a tela', () {
    test('método e decisão do contrato', () {
      expect(AccessMethod.qr.label, 'QR Code');
      expect(AccessMethod.nfc.label, 'NFC (aproximação)');
      expect(AccessMethod.fromCode('NFC'), AccessMethod.nfc);
      expect(() => AccessMethod.fromCode('BT'), throwsFormatException);
    });

    test('todos os motivos têm texto em português', () {
      for (final reason in DenialReason.values) {
        expect(reason.label, isNotEmpty, reason: reason.name);
      }
      expect(DenialReason.credentialExpired.label, 'QR Code fora da validade');
      expect(DenialReason.unknown.label, 'Motivo não informado');
    });

    test('filtro vira parâmetro da API', () {
      expect(AccessDecisionFilter.all.decision, isNull);
      expect(AccessDecisionFilter.granted.decision, AccessDecision.granted);
      expect(AccessDecisionFilter.denied.decision, AccessDecision.denied);
    });
  });

  group('AdminAccessEvent', () {
    Map<String, Object?> json({
      Object? decision = 'GRANTED',
      Object? reason,
      Object? user = const {
        'id': 'u',
        'name': 'Maria Souza',
        'role': 'RESIDENT',
      },
      Object? location = const {'id': 'l', 'name': 'Edifício Aurora'},
    }) => {
      'id': 'e1f2a3b4-1111-4222-8333-944455556666',
      'occurredAt': '2026-10-27T12:00:00.000',
      'terminalId': 'aurora-recepcao',
      'method': 'QR',
      'decision': decision,
      'reason': reason,
      'user': user,
      'location': location,
      'authorizationId': null,
      'distanceMeters': null,
    };

    test('evento liberado não tem motivo', () {
      final event = AdminAccessEvent.fromJson(json().cast<String, dynamic>());

      expect(event.decision, AccessDecision.granted);
      expect(event.reason, isNull);
      expect(event.decisionLabel, 'Liberado');
      expect(event.personLabel, 'Maria Souza');
      expect(event.locationLabel, 'Edifício Aurora');
    });

    test('evento negado mostra o motivo', () {
      final event = AdminAccessEvent.fromJson(
        json(
          decision: 'DENIED',
          reason: 'AUTHORIZATION_EXPIRED',
        ).cast<String, dynamic>(),
      );

      expect(event.decision, AccessDecision.denied);
      expect(event.reason, DenialReason.authorizationExpired);
      expect(event.decisionLabel, 'Negado');
      expect(
        event.accessibleLabel(now: DateTime(2026, 10, 27, 18)),
        'Negado, Maria Souza, QR Code, Edifício Aurora, motivo: '
        'Autorização expirada. Hoje · 12:00.',
      );
    });

    test('motivo desconhecido não derruba o evento', () {
      final event = AdminAccessEvent.fromJson(
        json(decision: 'DENIED', reason: 'ALIEN').cast<String, dynamic>(),
      );

      expect(event.reason, DenialReason.unknown);
      expect(event.reason?.label, 'Motivo não informado');
    });

    test('credencial e local ausentes ganham texto claro', () {
      final event = AdminAccessEvent.fromJson(
        json(user: null, location: null).cast<String, dynamic>(),
      );

      expect(event.personLabel, 'Credencial não identificada');
      expect(event.locationLabel, 'Local não identificado');
      expect(
        event.accessibleLabel(now: DateTime(2026, 10, 27, 18)),
        contains('credencial não identificada'),
      );
    });

    test('evento sem método ou decisão válidos é recusado', () {
      expect(
        () => AdminAccessEvent.fromJson(
          {...json(), 'method': 'BT'}.cast<String, dynamic>(),
        ),
        throwsFormatException,
      );
      expect(
        () => AdminAccessEvent.fromJson(
          {...json(), 'decision': 'MAYBE'}.cast<String, dynamic>(),
        ),
        throwsFormatException,
      );
    });

    test('a fixture usa o mesmo contrato', () {
      final event = accessEvent(decision: AccessDecision.denied);
      expect(event.decisionLabel, 'Negado');
      expect(eventsPageOf([event]).total, 1);
    });
  });
}
