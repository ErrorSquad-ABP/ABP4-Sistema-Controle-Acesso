import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:controle_acesso/features/authorizations/authorization_format.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _item({
  String id = '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  String status = 'ACTIVE',
  String? locationName = 'Edifício Aurora · Recepção',
  int maxUses = 5,
  int remainingUses = 3,
}) => {
  'id': id,
  'user': {
    'id': '5b0b1f8e-0f4f-4d0e-8d1f-9a4f5a6c7d8e',
    'name': 'Maria Souza',
    'email': 'maria.souza@exemplo.com',
    'role': 'VISITOR',
  },
  'location': locationName == null
      ? null
      : {'id': 'c1f2a3b4-1111-4222-8333-944455556666', 'name': locationName},
  'startsAt': '2026-10-27T17:00:00.000Z',
  'endsAt': '2026-10-27T21:00:00.000Z',
  'maxUses': maxUses,
  'usedCount': 2,
  'remainingUses': remainingUses,
  'status': status,
  'canceledAt': null,
  'cancelReason': null,
  'createdAt': '2026-10-26T12:00:00.000Z',
};

void main() {
  test('lê o envelope paginado e os campos que a lista usa', () {
    final page = AuthorizationPage.fromJson({
      'items': [_item()],
      'page': 1,
      'pageSize': 20,
      'total': 1,
    });

    final item = page.items.single;
    expect(page.total, 1);
    expect(item.locationName, 'Edifício Aurora · Recepção');
    expect(item.status, AuthorizationStatus.active);
    expect(item.maxUses, 5);
    expect(item.remainingUses, 3);
    expect(item.startsAt.isUtc, isTrue);
    expect(item.endsAt.isUtc, isTrue);
    expect(item.remainingFraction, closeTo(0.6, 0.0001));
  });

  test('usos acima do máximo não passam de uma barra cheia', () {
    final item = Authorization(
      id: 'id',
      locationName: 'Local',
      startsAt: DateTime.utc(2026),
      endsAt: DateTime.utc(2026),
      maxUses: 5,
      remainingUses: 7,
      status: AuthorizationStatus.active,
    );
    expect(item.remainingFraction, 1);
  });

  for (final status in AuthorizationStatus.values) {
    test('situação ${status.code} é aceita', () {
      final page = AuthorizationPage.fromJson({
        'items': [_item(status: status.code)],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      });
      expect(page.items.single.status, status);
    });
  }

  for (final (nome, body) in [
    ('situação desconhecida', _item(status: 'TALVEZ')),
    ('local nulo', _item(locationName: null)),
    (
      'local sem nome',
      {
        ..._item(),
        'location': {'id': 'x', 'name': '  '},
      },
    ),
    ('id vazio', _item(id: '')),
    ('usos negativos', _item(remainingUses: -1)),
    ('máximo zero', _item(maxUses: 0)),
    ('data inválida', {..._item(), 'startsAt': 'ontem'}),
  ]) {
    test('$nome vira FormatException', () {
      expect(
        () => AuthorizationPage.fromJson({
          'items': [body],
          'page': 1,
          'pageSize': 20,
          'total': 1,
        }),
        throwsFormatException,
      );
    });
  }

  test('item que não é objeto vira FormatException', () {
    expect(
      () => AuthorizationPage.fromJson({
        'items': ['x'],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      }),
      throwsFormatException,
    );
  });

  test('envelope incompleto vira FormatException', () {
    expect(
      () => AuthorizationPage.fromJson({'items': []}),
      throwsFormatException,
    );
  });

  test('Ativas lista todas as situações; Histórico, só as encerradas', () {
    for (final status in AuthorizationStatus.values) {
      expect(AuthorizationFilter.active.matches(status), isTrue);
      expect(
        AuthorizationFilter.history.matches(status),
        status == AuthorizationStatus.expired ||
            status == AuthorizationStatus.canceled,
        reason: status.code,
      );
    }
  });

  test('janela de hoje usa "Hoje" e o fuso do aparelho', () {
    expect(
      authorizationWindowLabel(
        startsAt: DateTime(2026, 10, 27, 14),
        endsAt: DateTime(2026, 10, 27, 18),
        now: DateTime(2026, 10, 27, 9),
      ),
      'Hoje · 14:00–18:00',
    );
  });

  test('outro dia mostra dia e mês; outro ano mostra o ano', () {
    expect(
      authorizationWindowLabel(
        startsAt: DateTime(2026, 11, 12, 8, 5),
        endsAt: DateTime(2026, 11, 12, 9),
        now: DateTime(2026, 10, 27, 9),
      ),
      '12/11 · 08:05–09:00',
    );
    expect(
      authorizationWindowLabel(
        startsAt: DateTime(2025, 12, 31, 22),
        endsAt: DateTime(2026, 1, 1, 2),
        now: DateTime(2026, 10, 27, 9),
      ),
      '31/12/2025 · 22:00–02:00',
    );
  });
}
